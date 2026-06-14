# Terraform Azure

Implementacion IaC para la tarea del proyecto integrador, usando servicios equivalentes en Azure.

| Requisito del PDF | AWS de referencia | Equivalente Azure en este repo |
| --- | --- | --- |
| Kubernetes administrado | EKS | Azure Kubernetes Service (`azurerm_kubernetes_cluster`) |
| Base de datos PostgreSQL | RDS PostgreSQL | Azure Database for PostgreSQL Flexible Server (`azurerm_postgresql_flexible_server`) o servidor existente |
| Almacenamiento / estado remoto | S3 | Azure Storage Account + Blob Container (`azurerm_storage_account`) |
| Lock de estado | DynamoDB | Blob lease locking nativo del backend `azurerm` |
| Registry de imagenes | ECR / GHCR | Azure Container Registry (`azurerm_container_registry`) |
| Observabilidad base | CloudWatch | Log Analytics + Azure Monitor para AKS |

Terraform puede trabajar en dos modos para PostgreSQL:

- `postgres_server_mode = "existing"`: referencia servidores PostgreSQL existentes y administra la regla de firewall para AKS.
- `postgres_server_mode = "create"`: crea un Azure PostgreSQL Flexible Server y la base `db_name`.

Los entornos actuales siguen usando servidores existentes en el resource group `dev-ops`:

- Staging/desarrollo usa `petclinic-dev-pg-20260613` / `petclinic_dev`
- Production usa `petclinic-prod-pg-20260613` / `petclinic_prod`

No escribir passwords en archivos `tfvars`. En modo `existing`, Terraform no necesita conocer el password de PostgreSQL. En modo `create`, el password administrador se pasa como variable sensible (`TF_VAR_postgres_admin_password`), pero puede quedar en el state remoto como valor sensible; por eso el backend debe mantenerse privado y con acceso restringido. El password usado por la aplicacion debe vivir en GitHub Secrets, Kubernetes Secret o el gestor de secretos usado por el despliegue.

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

## 4. Crear PostgreSQL para un ambiente nuevo

Crear un `tfvars` nuevo a partir de `env/new-database.tfvars.example` y usar un backend con un `key` unico, por ejemplo `review/petclinic.tfstate`.

```bash
cp env/new-database.tfvars.example env/review.tfvars
cp backend.review.hcl.example backend.review.hcl
export TF_VAR_postgres_admin_password='<password-seguro>'

terraform init -reconfigure -backend-config=backend.review.hcl
terraform plan -var-file=env/review.tfvars -out review.tfplan
terraform apply review.tfplan
```

En modo `create`, Terraform crea:

- Azure PostgreSQL Flexible Server
- Base PostgreSQL `db_name`
- Regla de firewall para la IP publica estatica de salida de AKS

La base creada tiene `prevent_destroy = true` para reducir el riesgo de borrado accidental. Para que Terraform administre una base existente, primero hay que importarla al state antes de activar `manage_postgres_database = true`.

## 5. Conectar kubectl, ACR y PostgreSQL

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
- PostgreSQL Flexible Server y base de datos cuando `postgres_server_mode = "create"`
- Regla de firewall en PostgreSQL para la IP publica estatica de salida de AKS
- Storage Account privado para artefactos
- Log Analytics Workspace para observabilidad de AKS
