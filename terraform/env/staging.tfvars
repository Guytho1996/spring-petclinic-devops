subscription_id     = "f51eb020-d024-4010-be44-279b64c4e2cc"
location            = "eastus2"
project_name        = "petclinic"
environment         = "staging"
resource_group_name = "petclinic-staging-rg"

vnet_address_space = ["10.40.0.0/16"]
aks_subnet_cidr    = "10.40.1.0/24"
aks_service_cidr   = "10.41.0.0/16"
aks_dns_service_ip = "10.41.0.10"
aks_node_count     = 1
aks_node_vm_size   = "Standard_B2s"
aks_sku_tier       = "Free"
acr_sku            = "Basic"

existing_postgres_server_name         = "petclinic-dev-pg-20260613"
existing_postgres_resource_group_name = "dev-ops"
db_name                               = "petclinic_dev"
db_admin_username                     = "petclinicadmin"

tags = {
  Owner  = "fabrica-software"
  Course = "devops"
}
