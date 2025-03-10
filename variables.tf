variable "agent_profile_grace_period_time_span" {
  type        = string
  default     = null
  description = "How long should the stateful machines be kept around. Maximum value is 7 days and the format must be in `d:hh:mm:ss`."
}

variable "agent_profile_kind" {
  type        = string
  default     = "Stateless"
  description = "The kind of agent profile."

  validation {
    condition     = can(index(["Stateless", "Stateful"], var.agent_profile_kind))
    error_message = "The agent_profile_kind must be one of: 'Stateless', 'Stateful'."
  }
}

variable "agent_profile_max_agent_lifetime" {
  type        = string
  default     = null
  description = "The maximum lifetime of the agent. Maximum value is 7 days and the format must be in `d:hh:mm:ss`."
}

variable "agent_profile_resource_prediction_profile" {
  type        = string
  default     = "Off"
  description = "The resource prediction profile for the agent, a.k.a `Stand by agent mode`, supported values are 'Off', 'Manual', 'Automatic', defaults to 'Off'."

  validation {
    condition     = can(index(["Off", "Manual", "Automatic"], var.agent_profile_resource_prediction_profile))
    error_message = "The agent_profile_resource_prediction_profile must be one of: 'None', 'Manual', 'Automatic'."
  }
}

variable "agent_profile_resource_prediction_profile_automatic" {
  type = object({
    kind                  = optional(string, "Automatic")
    prediction_preference = optional(string, "Balanced")
  })
  default = {
    kind                  = "Automatic"
    prediction_preference = "Balanced"
  }
  description = <<DESCRIPTION
The automatic resource prediction profile for the agent.

The object can have the following attributes:
- `kind` - (Required) The kind of prediction profile. Default is "Automatic".
- `prediction_preference` - (Required) The preference for resource prediction. Supported values are `Balanced`, `MostCostEffective`, `MoreCostEffective`, `MorePerformance`, and `BestPerformance`.
DESCRIPTION

  validation {
    condition     = var.agent_profile_resource_prediction_profile == "Automatic" || var.agent_profile_resource_prediction_profile_automatic != null
    error_message = "The input for agent_profile_resource_prediction_profile_automatic must be set when agent_profile_resource_prediction_profile is 'Automatic'."
  }
  validation {
    condition     = can(index(["Balanced", "MostCostEffective", "MoreCostEffective", "MorePerformance", "BestPerformance"], var.agent_profile_resource_prediction_profile_automatic.prediction_preference))
    error_message = "The prediction_preference must be one of: 'Balanced', 'MostCostEffective', 'MoreCostEffective', 'MorePerformance', 'BestPerformance'."
  }
}

variable "agent_profile_resource_prediction_profile_manual" {
  type = object({
    kind = string
  })
  default = {
    kind = "Manual"
  }
  description = "The manual resource prediction profile for the agent."
}

variable "agent_profile_resource_predictions_manual" {
  type = object({
    time_zone = optional(string, "UTC")
    days_data = optional(list(map(number)))
  })
  default = {
    days_data = [
      {
        "00:00:00" = 1
      }
    ]
  }
  description = <<DESCRIPTION
An object representing manual resource predictions for agent profiles, including time zone and optional daily schedules.

- `time_zone` - (Optional) The time zone for the agent profile. E.g. "Eastern Standard Time". Defaults to `UTC`. To see valid values for this run this command in PowerShell: `[System.TimeZoneInfo]::GetSystemTimeZones() | Select Id, BaseUtcOffSet`
- `days_data` - (Optional) A list representing the manual schedules. Defaults to a single standby agent constantly running.

The `days_data` list should contain one or seven maps. Supply one to apply the same schedule each day. Supply seven for a different schedule each day.

Examples:

- To set always having 1 agent available, you would use the following configuration:

  ```hcl
  agent_profile_resource_predictions_manual = {
    days_data = [
      {
        "00:00:00" = 1
      }
    ]
  }
  ```

- To set the schedule for every day to scale to one agent at 8:00 AM and scale down to zero agents at 5:00 PM, you would use the following configuration:

  ```hcl
  agent_profile_resource_predictions_manual = {
    time_zone = "Eastern Standard Time"
    days_data = [
      {
        "08:00:00" = 1
        "17:00:00" = 0
      }
    ]
  }
  ```

- To set a different schedule for each day, you would use the following configuration:

  ```hcl
  agent_profile_resource_predictions_manual = {
    time_zone = "Eastern Standard Time"
    days_data = [
      # Sunday
      {}, # Empty map to skip Sunday
      # Monday
      {
        "03:00:00" = 2  # Scale to 2 agents at 3:00 AM
        "08:00:00" = 4  # Scale to 4 agents at 8:00 AM
        "17:00:00" = 2  # Scale to 2 agents at 5:00 PM
        "22:00:00" = 0  # Scale to 0 agents at 10:00 PM
      },
      # Tuesday
      {
        "08:00:00" = 2
        "17:00:00" = 0
      },
      # Wednesday
      {
        "08:00:00" = 2
        "17:00:00" = 0
      },
      # Thursday
      {
        "08:00:00" = 2
        "17:00:00" = 0
      },
      # Friday
      {
        "08:00:00" = 2
        "17:00:00" = 0
      },
      # Saturday
      {} # Empty map to skip Saturday
    ]
  }
  ```

DESCRIPTION

  validation {
    condition     = var.agent_profile_resource_predictions_manual.days_data == null ? true : contains([1, 7], length(var.agent_profile_resource_predictions_manual.days_data))
    error_message = "The days_data list must contain one or seven maps."
  }
}

variable "dev_center_project_resource_id" {
  type        = string
  description = "(Required) The resource ID of the Dev Center project."
  nullable    = false
}

variable "fabric_profile_data_disks" {
  type = list(object({
    caching              = optional(string, "ReadWrite")
    disk_size_gigabytes  = optional(number, 100)
    drive_letter         = optional(string, null)
    storage_account_type = optional(string, "Premium_ZRS")
  }))
  default     = []
  description = <<DESCRIPTION
A list of objects representing the configuration for fabric profile data disks.

- `caching` - (Optional) The caching setting for the data disk. Valid values are `None`, `ReadOnly`, and `ReadWrite`. Defaults to `ReadWrite`.
- `disk_size_gigabytes` - (Optional) The size of the data disk in GiB. Defaults to 100GB.
- `drive_letter` - (Optional) The drive letter for the data disk, If you have any Windows agent images in your pool, choose a drive letter for your disk. If you don't specify a drive letter, `F` is used for VM sizes with a temporary disk; otherwise `E` is used. The drive letter must be a single letter except A, C, D, or E. If you are using a VM size without a temporary disk and want `E` as your drive letter, leave Drive Letter empty to get the default value of `E`.
- `storage_account_type` - (Optional) The storage account type for the data disk. Defaults to "Premium_ZRS".

Valid values for `storage_account_type` are:
- `Premium_LRS`
- `Premium_ZRS`
- `StandardSSD_LRS`
- `Standard_LRS`
DESCRIPTION
  nullable    = false

  validation {
    condition     = alltrue([for disk in var.fabric_profile_data_disks : can(index(["Premium_LRS", "Premium_ZRS", "StandardSSD_LRS", "Standard_LRS"], disk.storage_account_type))])
    error_message = "The storageAccountType must be one of: 'Premium_LRS', 'Premium_ZRS', 'StandardSSD_LRS', or `Standard_LRS`."
  }
}

variable "fabric_profile_images" {
  type = list(object({
    resource_id           = optional(string)
    well_known_image_name = optional(string)
    buffer                = optional(string, "*")
    aliases               = optional(list(string))
  }))
  default = [{
    well_known_image_name = "ubuntu-22.04/latest"
    aliases = [
      "ubuntu-22.04/latest"
    ]
  }]
  description = <<DESCRIPTION
The list of images to use for the fabric profile.

Each object in the list can have the following attributes:
- `resource_id` - (Optional) The resource ID of the image, this can either be resource ID of a Standard Azure VM Image or a Image that is hosted within Azure Image Gallery.
- `well_known_image_name` - (Optional) The well-known name of the image, thid is used to reference the well-known images that are available on Microsoft Hosted Agents, supported images are `ubuntu-22.04/latest`, `ubuntu-20.04/latest`, `windows-2022/latest`, and `windows-2019/latest`.
- `buffer` - (Optional) The buffer associated with the image.
- `aliases` - (Required) A list of aliases for the image.
DESCRIPTION
}

variable "fabric_profile_os_disk_storage_account_type" {
  type        = string
  default     = "Premium"
  description = "The storage account type for the OS disk, possible values are 'Standard', 'Premium' and 'StandardSSD', defaults to 'Premium'."

  validation {
    condition     = can(index(["Standard", "Premium", "StandardSSD"], var.fabric_profile_os_disk_storage_account_type))
    error_message = "The fabric_profile_os_disk_storage_account_type must be one of: 'Standard', 'Premium', 'StandardSSD'."
  }
}

variable "fabric_profile_os_profile_logon_type" {
  type        = string
  default     = "Service"
  description = "The logon type for the OS profile, possible values are 'Interactive' and 'Service', defaults to 'Service'."

  validation {
    condition     = can(index(["Interactive", "Service"], var.fabric_profile_os_profile_logon_type))
    error_message = "The fabric_profile_os_profile_logon_type must be one of: 'Interactive' or 'Service'."
  }
}

variable "fabric_profile_sku_name" {
  type        = string
  default     = "Standard_D2ads_v5"
  description = "The SKU name of the fabric profile, make sure you have enough quota for the SKU, the CPUs are multiplied by the `maximum_concurrency` value, make sure you request enough quota, defaults to 'Standard_D2ads_v5' which has 2 vCPU Cores. so if maximum_concurrency is 2, you will need quota for 4 vCPU Cores and so on."
}

variable "identity_ids" {
  description = "Specifies a list of user managed identity ids to be assigned to the VM."
  type        = list(string)
  default     = []
}

variable "identity_type" {
  description = "The Managed Service Identity Type of this Virtual Machine."
  type        = string
  default     = ""
}

variable "location" {
  type        = string
  description = "Azure region where the resource should be deployed."
  nullable    = false
}

variable "managed_pool_api_version" {
  type        = string
  description = "The API version to use for the Managed Pool resource."
  default     = "Microsoft.DevOpsInfrastructure/pools@2024-10-19"

}

variable "maximum_concurrency" {
  type        = number
  default     = 1
  description = "The maximum number of agents that can run concurrently, must be between 1 and 10000, defaults to 1."

  validation {
    condition     = var.maximum_concurrency >= 1 && var.maximum_concurrency <= 10000
    error_message = "The maximum_concurrency must be between 1 and 10000. Defaults to 10000"
  }
}

variable "name" {
  type        = string
  description = "Name of the pool. It needs to be globally unique for each Azure DevOps Organization."

  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9-.]{1,42}[a-zA-Z0-9-]$", var.name))
    error_message = "The name must be between 3 and 44 characters long, start with an alphanumeric character, end with an alphanumeric character or hyphen, and can only contain alphanumeric characters, hyphens, and dots."
  }
}

variable "organization_profile" {
  type = object({
    kind = optional(string, "AzureDevOps")
    organizations = list(object({
      name        = string
      projects    = optional(list(string), []) # List of all Projects names this agent should run on, if empty, it will run on all projects.
      parallelism = optional(number)           # If multiple organizations are specified, this value needs to be set, otherwise it will use the maximum_concurrency value.
    }))
    permission_profile = optional(object({
      kind   = optional(string, "CreatorOnly")
      users  = optional(list(string), null)
      groups = optional(list(string), null)
      }), {
      kind = "CreatorOnly"
    })
  })
  default     = null
  description = <<DESCRIPTION
An object representing the configuration for an organization profile, including organizations and permission profiles.

This is for advanced use cases where you need to specify permissions and multiple organization.

If not suppled, then `version_control_system_organization_name` and optionally `version_control_system_project_names` must be supplied.

- `organizations` - (Required) A list of objects representing the organizations.
  - `name` - (Required) The name of the organization, without the `https://dev.azure.com/` prefix.
  - `projects` - (Optional) A list of project names this agent should run on. If empty, it will run on all projects. Defaults to `[]`.
  - `parallelism` - (Optional) The parallelism value. If multiple organizations are specified, this value needs to be set and cannot exceed the total value of `maximum_concurrency`; otherwise, it will use the `maximum_concurrency` value as default or the value you define for single Organization.
- `permission_profile` - (Required) An object representing the permission profile.
  - `kind` - (Required) The kind of permission profile, possible values are `CreatorOnly`, `Inherit`, and `SpecificAccounts`, if `SpecificAccounts` is chosen, you must provide a list of users and/or groups.
  - `users` - (Optional) A list of users for the permission profile, supported value is the `ObjectID` or `UserPrincipalName`. Defaults to `null`.
  - `groups` - (Optional) A list of groups for the permission profile, supported value is the `ObjectID` of the group. Defaults to `null`.
DESCRIPTION
}

variable "rg_id" {
  type        = string
  description = "The resource group where the resources will be deployed."
}

variable "subnet_id" {
  type        = string
  default     = null
  description = "The virtual network subnet resource id to use for private networking."
}

variable "tags" {
  type        = map(string)
  default     = null
  description = "(Optional) Tags of the resource."
}

variable "version_control_system_organization_name" {
  type        = string
  default     = null
  description = "The name of the version control system organization. This is required if `organization_profile` is not supplied."
}

variable "version_control_system_project_names" {
  type        = set(string)
  default     = []
  description = "The name of the version control system project. This is optional if `organization_profile` is not supplied."
  nullable    = false
}

variable "version_control_system_type" {
  type        = string
  default     = "azuredevops"
  description = "The type of version control system. This is shortcut alternative to `organization_profile.kind`. Possible values are 'azuredevops' or 'github'."
  nullable    = false

  validation {
    condition     = can(index(["azuredevops", "github"], var.version_control_system_type))
    error_message = "The version_control_system_type must be one of: 'azuredevops' or 'github'."
  }
}
