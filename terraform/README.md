# Terraform Azure

Implementacion IaC para la tarea del proyecto integrador, usando servicios equivalentes en Azure.

| Requisito del PDF | AWS de referencia | Equivalente Azure en este repo |
| --- | --- | --- |
| Kubernetes administrado | EKS | Azure Kubernetes Service (`azurerm_kubernetes_cluster`) |
| Base de datos PostgreSQL | RDS PostgreSQL | Azure Database for PostgreSQL Flexible Server existente (`data.azurerm_postgresql_flexible_server`) |
| Almacenamiento / estado remoto | S3 | Azure Storage Account + Blob Container (`azurerm_storage_account`) |
| Lock de estado | DynamoDB | Blob lease locking nativo del backend `azurerm` |
| Registry de imagenes | ECR / GHCR | Azure Container Registry (`azurerm_container_registry`) |
| Observabilidad base | CloudWatch | Log Analytics + Azure Monitor para AKS |

La base de datos no se crea de nuevo: Terraform referencia servidores PostgreSQL existentes en el resource group `dev-ops`.

- Staging usa `petclinic-dev-pg-20260613` / `petclinic_dev`
- Production usa `petclinic-prod-pg-20260613` / `petclinic_prod`

El password de PostgreSQL no se guarda en Terraform ni en el state. Debe vivir en GitHub Secrets, Kubernetes Secret o el gestor de secretos usado por el despliegue.

## 1. Autenticacion

```bash
az login
az account set --subscription "<SUBSCRIPTION_ID>"
export ARM_USE_AZUREAD=true
```

## 2. Bootstrap del estado remoto

Terraform no puede crear el backend remoto dentro del mismo estado que intenta usar. Por eso el Storage Account de estado se crea una sola vez desde `terraform/bootstrap`.

```bash
cd terraform/bootstrap
terraform init
terraform apply -var="subscription_id=<SUBSCRIPTION_ID>"
```

Copiar el output `backend_hcl` en un archivo de backend local. Este workspace usa:

- `backend.staging.hcl` con key `staging/petclinic.tfstate`
- `backend.production.hcl` con key `production/petclinic.tfstate`

## 3. Provisionar infraestructura de la aplicacion

```bash
cd ..

terraform init -backend-config=backend.staging.hcl
terraform validate
terraform plan -var-file=env/staging.tfvars -out staging.tfplan
terraform apply staging.tfplan
```

Para produccion se usa otro state key/backend. El despliegue productivo pasa por el environment `production` de GitHub Actions con approval manual.

```bash
terraform init -reconfigure -backend-config=backend.production.hcl
terraform plan -var-file=env/production.tfvars -out production.tfplan
terraform apply production.tfplan
```

## 4. Conectar kubectl, ACR y PostgreSQL

```bash
$(terraform output -raw aks_get_credentials_command)
az acr login --name "$(terraform output -raw acr_name)"
terraform output -raw postgres_jdbc_url
```

El valor de `postgres_jdbc_url` se usa como `POSTGRES_URL` en Kubernetes o GitHub Actions. El usuario es `postgres_admin_username`; la clave debe venir de `POSTGRES_PASS`.

## Recursos creados

- Resource Group
- Virtual Network con subnet para AKS
- AKS con Managed Identity, OIDC issuer y Workload Identity
- ACR con permiso `AcrPull` para el kubelet de AKS
- Regla de firewall en PostgreSQL para la IP publica estatica de salida de AKS
- Storage Account privado para artefactos
- Log Analytics Workspace para observabilidad de AKS
