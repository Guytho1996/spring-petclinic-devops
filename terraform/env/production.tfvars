subscription_id     = "f51eb020-d024-4010-be44-279b64c4e2cc"
location            = "eastus2"
project_name        = "petclinic"
environment         = "production"
resource_group_name = "petclinic-production-rg"

vnet_address_space = ["10.42.0.0/16"]
aks_subnet_cidr    = "10.42.1.0/24"
aks_service_cidr   = "10.43.0.0/16"
aks_dns_service_ip = "10.43.0.10"
# Staging corre con 1 nodo para liberar cuota y permitir 2 nodos en production.
aks_node_count   = 2
aks_node_vm_size = "Standard_B2s"
aks_sku_tier     = "Free"
acr_sku          = "Basic"

existing_postgres_server_name         = "petclinic-prod-pg-20260613"
existing_postgres_resource_group_name = "dev-ops"
db_name                               = "petclinic_prod"
db_admin_username                     = "petclinicadmin"

tags = {
  Owner  = "fabrica-software"
  Course = "devops"
}
