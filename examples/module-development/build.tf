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

module "gallery" {
  source = "libre-devops/compute-gallery/azurerm"


  compute_gallery = [
    {
      rg_name  = module.rg.rg_name
      location = module.rg.rg_location
      tags     = module.rg.rg_tags

      name = local.gallery_name
    }
  ]
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
      scope         = format("/subscriptions/%s", data.azurerm_client_config.current_creds.subscription_id)
    }
  ]
}

module "images" {
  source = "registry.terraform.io/libre-devops/compute-gallery-image/azurerm"

  rg_name  = module.rg.rg_name
  location = module.rg.rg_location
  tags     = module.rg.rg_tags


  gallery_name = module.gallery.gallery_name[local.gallery_name]
  images = [
    {
      name                                = "AzDoWindows2022AzureEdition"
      description                         = "Azure DevOps image based on Windows 2022 Azure Edition image"
      specialised                         = false
      hyper_v_generation                  = "V2"
      os_type                             = "Windows"
      accelerated_network_support_enabled = true
      max_recommended_vcpu                = 16
      min_recommended_vcpu                = 2
      max_recommended_memory_in_gb        = 32
      min_recommended_memory_in_gb        = 8

      identifier = {
        offer     = "Azdo${var.short}${var.env}WindowsServer"
        publisher = "LibreDevOps"
        sku       = "AzdoWin2022AzureEdition"
      }
    }
  ]
}


module "devops_managed_pool" {

  depends_on = [module.role_assignments]
  source     = "../../"

  rg_id    = module.rg.rg_id
  location = module.rg.rg_location
  tags     = module.rg.rg_tags

  fabric_profile_images = [
    {
      well_known_image_name = "ubuntu-22.04/latest"
      aliases = [
        "ubuntu-22.04/latest"
      ]
    },
    # {
    #   resource_id = module.images.image_id[0]
    #     aliases = [
    #         "AzDoWindows2022AzureEdition"
    #     ]
    # }
  ]

  name                           = local.devops_managed_pool_name
  dev_center_project_resource_id = module.dev_centers.dev_center_project_id[local.dev_center_name]

  version_control_system_organization_name = "libredevops"
  version_control_system_project_names     = ["libredevops"]
  subnet_id                                = module.network.subnets_ids[local.devops_subnet_name]

  identity_type = "UserAssigned"
  identity_ids  = [azurerm_user_assigned_identity.uid.id]
}
