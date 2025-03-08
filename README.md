```hcl
resource "azapi_resource" "managed_devops_pool" {
  type = var.managed_pool_api_version
  body = {
    properties = {
      devCenterProjectResourceId = var.dev_center_project_resource_id
      maximumConcurrency         = var.maximum_concurrency
      organizationProfile = {
        kind              = local.version_control_system_type
        organizations     = local.organization_profile.organizations
        permissionProfile = local.organization_profile.permission_profile
      }

      agentProfile = local.agent_profile

      fabricProfile = {
        sku = {
          name = var.fabric_profile_sku_name
        }
        images = [for image in var.fabric_profile_images : {
          wellKnownImageName = image.well_known_image_name
          aliases            = image.aliases
          buffer             = image.buffer
          resourceId         = image.resource_id
        }]

        networkProfile = var.subnet_id != null ? {
          subnetId = var.subnet_id
        } : null
        osProfile = {
          logonType = var.fabric_profile_os_profile_logon_type
        }
        storageProfile = {
          osDiskStorageAccountType = var.fabric_profile_os_disk_storage_account_type
          dataDisks = [for data_disk in var.fabric_profile_data_disks : {
            diskSizeGiB        = data_disk.disk_size_gigabytes
            caching            = data_disk.caching
            driveLetter        = data_disk.drive_letter
            storageAccountType = data_disk.storage_account_type
          }]
        }
        kind = "Vmss"
      }
    }
  }
  location                  = var.location
  name                      = var.name
  parent_id                 = var.rg_id
  schema_validation_enabled = false
  tags                      = var.tags

  dynamic "identity" {
    for_each = length(var.identity_ids) == 0 && var.identity_type == "SystemAssigned" ? [var.identity_type] : []
    content {
      type = var.identity_type
    }
  }

  dynamic "identity" {
    for_each = var.identity_type == "UserAssigned" ? [var.identity_type] : []
    content {
      type         = var.identity_type
      identity_ids = length(var.identity_ids) > 0 ? var.identity_ids : []
    }
  }

  dynamic "identity" {
    for_each = var.identity_type == "SystemAssigned, UserAssigned" ? [var.identity_type] : []
    content {
      type         = var.identity_type
      identity_ids = length(var.identity_ids) > 0 ? var.identity_ids : []
    }
  }


}
```
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azapi"></a> [azapi](#provider\_azapi) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azapi_resource.managed_devops_pool](https://registry.terraform.io/providers/Azure/azapi/latest/docs/resources/resource) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_agent_profile_grace_period_time_span"></a> [agent\_profile\_grace\_period\_time\_span](#input\_agent\_profile\_grace\_period\_time\_span) | How long should the stateful machines be kept around. Maximum value is 7 days and the format must be in `d:hh:mm:ss`. | `string` | `null` | no |
| <a name="input_agent_profile_kind"></a> [agent\_profile\_kind](#input\_agent\_profile\_kind) | The kind of agent profile. | `string` | `"Stateless"` | no |
| <a name="input_agent_profile_max_agent_lifetime"></a> [agent\_profile\_max\_agent\_lifetime](#input\_agent\_profile\_max\_agent\_lifetime) | The maximum lifetime of the agent. Maximum value is 7 days and the format must be in `d:hh:mm:ss`. | `string` | `null` | no |
| <a name="input_agent_profile_resource_prediction_profile"></a> [agent\_profile\_resource\_prediction\_profile](#input\_agent\_profile\_resource\_prediction\_profile) | The resource prediction profile for the agent, a.k.a `Stand by agent mode`, supported values are 'Off', 'Manual', 'Automatic', defaults to 'Off'. | `string` | `"Off"` | no |
| <a name="input_agent_profile_resource_prediction_profile_automatic"></a> [agent\_profile\_resource\_prediction\_profile\_automatic](#input\_agent\_profile\_resource\_prediction\_profile\_automatic) | The automatic resource prediction profile for the agent.<br/><br/>The object can have the following attributes:<br/>- `kind` - (Required) The kind of prediction profile. Default is "Automatic".<br/>- `prediction_preference` - (Required) The preference for resource prediction. Supported values are `Balanced`, `MostCostEffective`, `MoreCostEffective`, `MorePerformance`, and `BestPerformance`. | <pre>object({<br/>    kind                  = optional(string, "Automatic")<br/>    prediction_preference = optional(string, "Balanced")<br/>  })</pre> | <pre>{<br/>  "kind": "Automatic",<br/>  "prediction_preference": "Balanced"<br/>}</pre> | no |
| <a name="input_agent_profile_resource_prediction_profile_manual"></a> [agent\_profile\_resource\_prediction\_profile\_manual](#input\_agent\_profile\_resource\_prediction\_profile\_manual) | The manual resource prediction profile for the agent. | <pre>object({<br/>    kind = string<br/>  })</pre> | <pre>{<br/>  "kind": "Manual"<br/>}</pre> | no |
| <a name="input_agent_profile_resource_predictions_manual"></a> [agent\_profile\_resource\_predictions\_manual](#input\_agent\_profile\_resource\_predictions\_manual) | An object representing manual resource predictions for agent profiles, including time zone and optional daily schedules.<br/><br/>- `time_zone` - (Optional) The time zone for the agent profile. E.g. "Eastern Standard Time". Defaults to `UTC`. To see valid values for this run this command in PowerShell: `[System.TimeZoneInfo]::GetSystemTimeZones() | Select Id, BaseUtcOffSet`<br/>- `days_data` - (Optional) A list representing the manual schedules. Defaults to a single standby agent constantly running.<br/><br/>The `days_data` list should contain one or seven maps. Supply one to apply the same schedule each day. Supply seven for a different schedule each day.<br/><br/>Examples:<br/><br/>- To set always having 1 agent available, you would use the following configuration:<pre>hcl<br/>  agent_profile_resource_predictions_manual = {<br/>    days_data = [<br/>      {<br/>        "00:00:00" = 1<br/>      }<br/>    ]<br/>  }</pre>- To set the schedule for every day to scale to one agent at 8:00 AM and scale down to zero agents at 5:00 PM, you would use the following configuration:<pre>hcl<br/>  agent_profile_resource_predictions_manual = {<br/>    time_zone = "Eastern Standard Time"<br/>    days_data = [<br/>      {<br/>        "08:00:00" = 1<br/>        "17:00:00" = 0<br/>      }<br/>    ]<br/>  }</pre>- To set a different schedule for each day, you would use the following configuration:<pre>hcl<br/>  agent_profile_resource_predictions_manual = {<br/>    time_zone = "Eastern Standard Time"<br/>    days_data = [<br/>      # Sunday<br/>      {}, # Empty map to skip Sunday<br/>      # Monday<br/>      {<br/>        "03:00:00" = 2  # Scale to 2 agents at 3:00 AM<br/>        "08:00:00" = 4  # Scale to 4 agents at 8:00 AM<br/>        "17:00:00" = 2  # Scale to 2 agents at 5:00 PM<br/>        "22:00:00" = 0  # Scale to 0 agents at 10:00 PM<br/>      },<br/>      # Tuesday<br/>      {<br/>        "08:00:00" = 2<br/>        "17:00:00" = 0<br/>      },<br/>      # Wednesday<br/>      {<br/>        "08:00:00" = 2<br/>        "17:00:00" = 0<br/>      },<br/>      # Thursday<br/>      {<br/>        "08:00:00" = 2<br/>        "17:00:00" = 0<br/>      },<br/>      # Friday<br/>      {<br/>        "08:00:00" = 2<br/>        "17:00:00" = 0<br/>      },<br/>      # Saturday<br/>      {} # Empty map to skip Saturday<br/>    ]<br/>  }</pre> | <pre>object({<br/>    time_zone = optional(string, "UTC")<br/>    days_data = optional(list(map(number)))<br/>  })</pre> | <pre>{<br/>  "days_data": [<br/>    {<br/>      "00:00:00": 1<br/>    }<br/>  ]<br/>}</pre> | no |
| <a name="input_dev_center_project_resource_id"></a> [dev\_center\_project\_resource\_id](#input\_dev\_center\_project\_resource\_id) | (Required) The resource ID of the Dev Center project. | `string` | n/a | yes |
| <a name="input_fabric_profile_data_disks"></a> [fabric\_profile\_data\_disks](#input\_fabric\_profile\_data\_disks) | A list of objects representing the configuration for fabric profile data disks.<br/><br/>- `caching` - (Optional) The caching setting for the data disk. Valid values are `None`, `ReadOnly`, and `ReadWrite`. Defaults to `ReadWrite`.<br/>- `disk_size_gigabytes` - (Optional) The size of the data disk in GiB. Defaults to 100GB.<br/>- `drive_letter` - (Optional) The drive letter for the data disk, If you have any Windows agent images in your pool, choose a drive letter for your disk. If you don't specify a drive letter, `F` is used for VM sizes with a temporary disk; otherwise `E` is used. The drive letter must be a single letter except A, C, D, or E. If you are using a VM size without a temporary disk and want `E` as your drive letter, leave Drive Letter empty to get the default value of `E`.<br/>- `storage_account_type` - (Optional) The storage account type for the data disk. Defaults to "Premium\_ZRS".<br/><br/>Valid values for `storage_account_type` are:<br/>- `Premium_LRS`<br/>- `Premium_ZRS`<br/>- `StandardSSD_LRS`<br/>- `Standard_LRS` | <pre>list(object({<br/>    caching              = optional(string, "ReadWrite")<br/>    disk_size_gigabytes  = optional(number, 100)<br/>    drive_letter         = optional(string, null)<br/>    storage_account_type = optional(string, "Premium_ZRS")<br/>  }))</pre> | `[]` | no |
| <a name="input_fabric_profile_images"></a> [fabric\_profile\_images](#input\_fabric\_profile\_images) | The list of images to use for the fabric profile.<br/><br/>Each object in the list can have the following attributes:<br/>- `resource_id` - (Optional) The resource ID of the image, this can either be resource ID of a Standard Azure VM Image or a Image that is hosted within Azure Image Gallery.<br/>- `well_known_image_name` - (Optional) The well-known name of the image, thid is used to reference the well-known images that are available on Microsoft Hosted Agents, supported images are `ubuntu-22.04/latest`, `ubuntu-20.04/latest`, `windows-2022/latest`, and `windows-2019/latest`.<br/>- `buffer` - (Optional) The buffer associated with the image.<br/>- `aliases` - (Required) A list of aliases for the image. | <pre>list(object({<br/>    resource_id           = optional(string)<br/>    well_known_image_name = optional(string)<br/>    buffer                = optional(string, "*")<br/>    aliases               = optional(list(string))<br/>  }))</pre> | <pre>[<br/>  {<br/>    "aliases": [<br/>      "ubuntu-22.04/latest"<br/>    ],<br/>    "well_known_image_name": "ubuntu-22.04/latest"<br/>  }<br/>]</pre> | no |
| <a name="input_fabric_profile_os_disk_storage_account_type"></a> [fabric\_profile\_os\_disk\_storage\_account\_type](#input\_fabric\_profile\_os\_disk\_storage\_account\_type) | The storage account type for the OS disk, possible values are 'Standard', 'Premium' and 'StandardSSD', defaults to 'Premium'. | `string` | `"Premium"` | no |
| <a name="input_fabric_profile_os_profile_logon_type"></a> [fabric\_profile\_os\_profile\_logon\_type](#input\_fabric\_profile\_os\_profile\_logon\_type) | The logon type for the OS profile, possible values are 'Interactive' and 'Service', defaults to 'Service'. | `string` | `"Service"` | no |
| <a name="input_fabric_profile_sku_name"></a> [fabric\_profile\_sku\_name](#input\_fabric\_profile\_sku\_name) | The SKU name of the fabric profile, make sure you have enough quota for the SKU, the CPUs are multiplied by the `maximum_concurrency` value, make sure you request enough quota, defaults to 'Standard\_D2ads\_v5' which has 2 vCPU Cores. so if maximum\_concurrency is 2, you will need quota for 4 vCPU Cores and so on. | `string` | `"Standard_D2ads_v5"` | no |
| <a name="input_identity_ids"></a> [identity\_ids](#input\_identity\_ids) | Specifies a list of user managed identity ids to be assigned to the VM. | `list(string)` | `[]` | no |
| <a name="input_identity_type"></a> [identity\_type](#input\_identity\_type) | The Managed Service Identity Type of this Virtual Machine. | `string` | `""` | no |
| <a name="input_location"></a> [location](#input\_location) | Azure region where the resource should be deployed. | `string` | n/a | yes |
| <a name="input_managed_pool_api_version"></a> [managed\_pool\_api\_version](#input\_managed\_pool\_api\_version) | The API version to use for the Managed Pool resource. | `string` | `"Microsoft.DevOpsInfrastructure/pools@2024-10-19"` | no |
| <a name="input_maximum_concurrency"></a> [maximum\_concurrency](#input\_maximum\_concurrency) | The maximum number of agents that can run concurrently, must be between 1 and 10000, defaults to 1. | `number` | `1` | no |
| <a name="input_name"></a> [name](#input\_name) | Name of the pool. It needs to be globally unique for each Azure DevOps Organization. | `string` | n/a | yes |
| <a name="input_organization_profile"></a> [organization\_profile](#input\_organization\_profile) | An object representing the configuration for an organization profile, including organizations and permission profiles.<br/><br/>This is for advanced use cases where you need to specify permissions and multiple organization.<br/><br/>If not suppled, then `version_control_system_organization_name` and optionally `version_control_system_project_names` must be supplied.<br/><br/>- `organizations` - (Required) A list of objects representing the organizations.<br/>  - `name` - (Required) The name of the organization, without the `https://dev.azure.com/` prefix.<br/>  - `projects` - (Optional) A list of project names this agent should run on. If empty, it will run on all projects. Defaults to `[]`.<br/>  - `parallelism` - (Optional) The parallelism value. If multiple organizations are specified, this value needs to be set and cannot exceed the total value of `maximum_concurrency`; otherwise, it will use the `maximum_concurrency` value as default or the value you define for single Organization.<br/>- `permission_profile` - (Required) An object representing the permission profile.<br/>  - `kind` - (Required) The kind of permission profile, possible values are `CreatorOnly`, `Inherit`, and `SpecificAccounts`, if `SpecificAccounts` is chosen, you must provide a list of users and/or groups.<br/>  - `users` - (Optional) A list of users for the permission profile, supported value is the `ObjectID` or `UserPrincipalName`. Defaults to `null`.<br/>  - `groups` - (Optional) A list of groups for the permission profile, supported value is the `ObjectID` of the group. Defaults to `null`. | <pre>object({<br/>    kind = optional(string, "AzureDevOps")<br/>    organizations = list(object({<br/>      name        = string<br/>      projects    = optional(list(string), []) # List of all Projects names this agent should run on, if empty, it will run on all projects.<br/>      parallelism = optional(number)           # If multiple organizations are specified, this value needs to be set, otherwise it will use the maximum_concurrency value.<br/>    }))<br/>    permission_profile = optional(object({<br/>      kind   = optional(string, "CreatorOnly")<br/>      users  = optional(list(string), null)<br/>      groups = optional(list(string), null)<br/>      }), {<br/>      kind = "CreatorOnly"<br/>    })<br/>  })</pre> | `null` | no |
| <a name="input_rg_id"></a> [rg\_id](#input\_rg\_id) | The resource group where the resources will be deployed. | `string` | n/a | yes |
| <a name="input_subnet_id"></a> [subnet\_id](#input\_subnet\_id) | The virtual network subnet resource id to use for private networking. | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | (Optional) Tags of the resource. | `map(string)` | `null` | no |
| <a name="input_version_control_system_organization_name"></a> [version\_control\_system\_organization\_name](#input\_version\_control\_system\_organization\_name) | The name of the version control system organization. This is required if `organization_profile` is not supplied. | `string` | `null` | no |
| <a name="input_version_control_system_project_names"></a> [version\_control\_system\_project\_names](#input\_version\_control\_system\_project\_names) | The name of the version control system project. This is optional if `organization_profile` is not supplied. | `set(string)` | `[]` | no |
| <a name="input_version_control_system_type"></a> [version\_control\_system\_type](#input\_version\_control\_system\_type) | The type of version control system. This is shortcut alternative to `organization_profile.kind`. Possible values are 'azuredevops' or 'github'. | `string` | `"azuredevops"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_devops_pool_id"></a> [devops\_pool\_id](#output\_devops\_pool\_id) | The resource if of the Managed DevOps Pool. |
| <a name="output_devops_pool_name"></a> [devops\_pool\_name](#output\_devops\_pool\_name) | The name of the Managed DevOps Pool. |
| <a name="output_devops_pool_tags"></a> [devops\_pool\_tags](#output\_devops\_pool\_tags) | The tags of the Managed DevOps Pool. |
| <a name="output_resource"></a> [resource](#output\_resource) | This is the full output for the Managed DevOps Pool. |
