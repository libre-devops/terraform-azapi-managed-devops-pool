```hcl
locals {
  rg_name                     = "rg-${var.short}-${var.loc}-${var.env}-02"
  vnet_name                   = "vnet-${var.short}-${var.loc}-${var.env}-02"
  dev_center_name             = "devc-${var.short}-${var.loc}-${var.env}-01"
  nsg_name                    = "nsg-${var.short}-${var.loc}-${var.env}-01"
  devops_subnet_name          = "DevOpsInfraSubnet"
  dev_center_subnet_name      = "DevCenterSubnet"
  user_assigned_identity_name = "devops-id-${var.short}-${var.loc}-${var.env}-01"
  gallery_name                = "gal${var.short}${var.loc}${var.env}01"
  devops_managed_pool_name    = "devops-${var.short}-${var.loc}-${var.env}-01"
  devops_infra_spn_object_id  = "ad509155-538b-4995-84e8-e77ab41d25c9" # Microsoft managed
}

module "rg" {
  source = "libre-devops/rg/azurerm"

  rg_name  = local.rg_name
  location = local.location
  tags     = local.tags
}

module "shared_vars" {
  source = "libre-devops/shared-vars/azurerm"
}

locals {
  lookup_cidr = {
    for landing_zone, envs in module.shared_vars.cidrs : landing_zone => {
      for env, cidr in envs : env => cidr
    }
  }
}

resource "azurerm_user_assigned_identity" "uid" {
  resource_group_name = module.rg.rg_name
  location            = module.rg.rg_location
  tags                = module.rg.rg_tags

  name = local.user_assigned_identity_name
}

module "subnet_calculator" {
  source = "libre-devops/subnet-calculator/null"

  base_cidr = local.lookup_cidr[var.short][var.env][0]
  subnets = {
    (local.devops_subnet_name) = {
      mask_size = 26
      netnum    = 0
    }
    (local.dev_center_subnet_name) = {
      mask_size = 26
      netnum    = 1
    }
  }
}

module "network" {
  source = "libre-devops/network/azurerm"

  rg_name  = module.rg.rg_name
  location = module.rg.rg_location
  tags     = module.rg.rg_tags

  vnet_name          = local.vnet_name
  vnet_location      = module.rg.rg_location
  vnet_address_space = [module.subnet_calculator.base_cidr]

  subnets = {
    for i, name in module.subnet_calculator.subnet_names :
    name => {
      address_prefixes  = toset([module.subnet_calculator.subnet_ranges[i]])
      service_endpoints = []

      delegation = name == (local.devops_subnet_name) ? [
        {
          type = "Microsoft.DevOpsInfrastructure/pools"
        }
        ] : name == (local.dev_center_subnet_name) ? [
        {
          type = "Microsoft.DevCenter/networkConnection"
        }
      ] : []
    }
  }
}


module "nsg" {
  source = "libre-devops/nsg/azurerm"

  rg_name  = module.rg.rg_name
  location = module.rg.rg_location
  tags     = module.rg.rg_tags

  nsg_name              = local.nsg_name
  associate_with_subnet = true
  subnet_id             = module.network.subnets_ids[local.devops_subnet_name]
  custom_nsg_rules = {
    "AllowVnetInbound" = {
      priority                   = 100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "*"
      source_address_prefix      = "VirtualNetwork"
      destination_address_prefix = "VirtualNetwork"
    },
    "AllowDevBoxInbound" = {
      priority                   = 105
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "*"
      source_address_prefix      = "VirtualNetwork"
      destination_address_prefix = "WindowsVirtualDesktop"
    },
  }
}


module "dev_centers" {
  source = "../../../terraform-azurerm-dev-center"

  dev_centers = [
    {
      rg_name  = module.rg.rg_name
      location = module.rg.rg_location
      tags     = module.rg.rg_tags

      identity_type = "SystemAssigned"

      name = local.dev_center_name

      network_connection = {
        subnet_id = module.network.subnets_ids[local.dev_center_subnet_name]
      }

      create_compute_gallery = true
      compute_gallery = {
        name     = local.gallery_name
        rg_name  = module.rg.rg_name
        location = module.rg.rg_location
        tags     = module.rg.rg_tags
      }
      create_project = true
      project = {
        description                = "This is the first Dev Center project."
        maximum_dev_boxes_per_user = 1
      },
    }
  ]
}


module "role_assignments" {
  source = "libre-devops/role-assignment/azurerm"

  role_assignments = [
    {
      principal_ids = [local.devops_infra_spn_object_id]
      role_names    = ["Network Contributor", "Reader"]
      scope         = module.rg.rg_id
    },
    {
      principal_ids = [azurerm_user_assigned_identity.uid.principal_id]
      role_names    = ["Owner", "Contributor"]
      scope         = data.azurerm_client_config.current_creds.subscription_id
    }
  ]
}


module "dev" {

  depends_on = [module.role_assignments]
  source     = "../../"

  rg_name  = module.rg.rg_name
  location = module.rg.rg_location
  tags     = module.rg.rg_tags

  name                           = local.devops_managed_pool_name
  dev_center_project_resource_id = module.dev_centers.dev_center_project[local.dev_center_name].id

  version_control_system_organization_name = "libredevops"
  version_control_system_project_names     = ["libredevops"]
  subnet_id                                = module.network.subnets_ids[local.devops_subnet_name]

  identity_type = "UserAssigned"
  identity_ids  = [azurerm_user_assigned_identity.uid.id]
}
```
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | 4.22.0 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.7.1 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_dev"></a> [dev](#module\_dev) | ../../ | n/a |
| <a name="module_dev_centers"></a> [dev\_centers](#module\_dev\_centers) | ../../../terraform-azurerm-dev-center | n/a |
| <a name="module_network"></a> [network](#module\_network) | libre-devops/network/azurerm | n/a |
| <a name="module_nsg"></a> [nsg](#module\_nsg) | libre-devops/nsg/azurerm | n/a |
| <a name="module_rg"></a> [rg](#module\_rg) | libre-devops/rg/azurerm | n/a |
| <a name="module_role_assignments"></a> [role\_assignments](#module\_role\_assignments) | libre-devops/role-assignment/azurerm | n/a |
| <a name="module_shared_vars"></a> [shared\_vars](#module\_shared\_vars) | libre-devops/shared-vars/azurerm | n/a |
| <a name="module_subnet_calculator"></a> [subnet\_calculator](#module\_subnet\_calculator) | libre-devops/subnet-calculator/null | n/a |

## Resources

| Name | Type |
|------|------|
| [azurerm_user_assigned_identity.uid](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/user_assigned_identity) | resource |
| [random_string.entropy](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [azurerm_client_config.current_creds](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/client_config) | data source |
| [azurerm_key_vault.mgmt_kv](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault) | data source |
| [azurerm_resource_group.mgmt_rg](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/resource_group) | data source |
| [azurerm_ssh_public_key.mgmt_ssh_key](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/ssh_public_key) | data source |
| [azurerm_user_assigned_identity.mgmt_user_assigned_id](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/user_assigned_identity) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_Regions"></a> [Regions](#input\_Regions) | Converts shorthand name to longhand name via lookup on map list | `map(string)` | <pre>{<br/>  "eus": "East US",<br/>  "euw": "West Europe",<br/>  "uks": "UK South",<br/>  "ukw": "UK West"<br/>}</pre> | no |
| <a name="input_env"></a> [env](#input\_env) | This is passed as an environment variable, it is for the shorthand environment tag for resource.  For example, production = prod | `string` | `"prd"` | no |
| <a name="input_loc"></a> [loc](#input\_loc) | The shorthand name of the Azure location, for example, for UK South, use uks.  For UK West, use ukw. Normally passed as TF\_VAR in pipeline | `string` | `"uks"` | no |
| <a name="input_name"></a> [name](#input\_name) | The name of this resource | `string` | `"tst"` | no |
| <a name="input_short"></a> [short](#input\_short) | This is passed as an environment variable, it is for a shorthand name for the environment, for example hello-world = hw | `string` | `"lbd"` | no |
| <a name="input_static_tags"></a> [static\_tags](#input\_static\_tags) | The tags variable | `map(string)` | <pre>{<br/>  "Contact": "info@cyber.scot",<br/>  "CostCentre": "671888",<br/>  "ManagedBy": "Terraform"<br/>}</pre> | no |

## Outputs

No outputs.
