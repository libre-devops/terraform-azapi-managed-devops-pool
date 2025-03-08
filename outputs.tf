output "devops_pool_id" {
  description = "The resource if of the Managed DevOps Pool."
  value       = azapi_resource.managed_devops_pool.id
}

output "devops_pool_name" {
  description = "The name of the Managed DevOps Pool."
  value       = azapi_resource.managed_devops_pool.name
}

output "devops_pool_tags" {
  description = "The tags of the Managed DevOps Pool."
  value       = azapi_resource.managed_devops_pool.tags
}

output "resource" {
  description = "This is the full output for the Managed DevOps Pool."
  value       = azapi_resource.managed_devops_pool
}
