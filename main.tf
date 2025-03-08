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