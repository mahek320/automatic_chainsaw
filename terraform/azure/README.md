# Azure Terraform Baseline

This repository provisions a reusable Azure landing zone that includes:

- A resource group (defaults to `soundar-rnd-01` in `eastus`).
- A /24 virtual network with five explicitly defined subnets (App Gateway, Container Apps, VM, Private Endpoints, Future Buffer).
- A Standard NAT Gateway with its own static public IP, attached to every subnet for secure outbound access.
- A hardened Ubuntu 24.04 LTS VM (`Standard_D2s_v3`, 30 GiB OS disk) deployed into the VM subnet with a randomly generated 8-digit password.
- Cloud-init bootstrapping that installs nginx, Docker, and docker compose, adds the admin user to the docker group, and enables both services at boot.
- Azure Monitor integration via Log Analytics + AMA/DCR that streams CPU, memory, disk, syslog, nginx, and Docker container logs into VM Insights (with an optional dependency map view when the Service Map extension is supported on the chosen distro).
- Daily VM backups with a 7-day retention policy stored in a Recovery Services vault, plus a delete lock to prevent accidental removal of the VM.
- Host-based disk encryption turned on for the Ubuntu VM plus a system-assigned managed identity for keyless access to other Azure resources.
- An Azure Storage Account + private blob container that acts like an S3 bucket for application backups, with the VM's managed identity granted `Storage Blob Data Contributor` access.
- A Premium Azure Container Registry (ACR) with a lifecycle retention policy (7 untagged revisions) and managed identity RBAC (`AcrPush`) so the VM can push/pull images without stored credentials.

Everything is parameterized so that you can override resource names, regions, VNet CIDRs, subnet names, and tagging through a tfvars file.

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/downloads) v1.6+.
- Azure subscription access (Subscription ID `07512706-3bc2-4200-9b89-5bce3249bddb`).
- Azure CLI (`az`) logged in to the `respective` directory.
- An Azure AD service principal with permission to create resource groups, network resources, and VMs (see below).

## Quick start

1. **Clone / copy** this folder locally.
2. **Create your input file** based on `terraform.tfvars.example`:
    - **Windows (PowerShell):**
       ```powershell
       cd "/terraform/azure"
       copy terraform.tfvars.example terraform.tfvars
       ```
    - **Linux/macOS (bash):**
       ```bash
       cd "terraform/azure"
       cp terraform.tfvars.example terraform.tfvars
       ```
    Adjust values (resource group, region, CIDRs, tags, etc.) as needed. Leave `allowed_ssh_cidrs` empty to restrict SSH to the virtual network, or add explicit trusted ranges (e.g., `"203.0.113.4/32"`).
   Add your current public workstation IP to `key_vault_allowed_ip_rules` so Terraform can reach Key Vault data-plane APIs while the firewall default action remains `Deny`.
3. **Authenticate with Azure** using the service principal credentials (see next section) or your user account:
    - **PowerShell:**
       ```powershell
       az login --service-principal --username <appId> --password <password> --tenant <tenantId>
       az account set --subscription 07512706-3bc2-4200-9b89-5bce3249bddb
       ```
    - **bash:**
       ```bash
       az login --service-principal --username <appId> --password <password> --tenant <tenantId>
       az account set --subscription 07512706-3bc2-4200-9b89-5bce3249bddb
       ```
4. **Initialize and deploy**:
    - **PowerShell:**
       ```powershell
       terraform init
       terraform plan -out main.tfplan
       terraform apply main.tfplan
       ```
    - **bash:**
       ```bash
       terraform init
       terraform plan -out main.tfplan
       terraform apply main.tfplan
       ```

Terraform outputs the VM username (`soundar-rnd-01` by default) and an auto-generated 8-digit password (`vm_admin_password`). Use those credentials to log into the Ubuntu VM over SSH from an allowed network path.

### Import existing VM extensions (AMA / Dependency Agent)

If you previously enabled VM Insights from the Azure Portal, the VM may already have the **Azure Monitor Agent** and **Dependency Agent** extensions installed. Terraform cannot recreate an existing extension, so you must import it into state before running `terraform apply`. A helper script is included to streamline the process:

```powershell
cd "/terraform/azure"
terraform init
scripts/import-existing-vm-extensions.ps1 `
   -SubscriptionId "<subscription-guid>" `
   -ResourceGroupName "soundar-rnd-01" `
   -VmName "soundar-rnd-01-vm" `
   -AzureMonitorExtensionName "soundar-ama-ext" `
   -DependencyExtensionName "soundar-dependency-ext"
```

- Run `az login` (or ensure your service principal session is active) before invoking the script.
- Override the extension names only if you changed `azure_monitor_agent_extension_name` / `dependency_agent_extension_name` in your tfvars.
- The script first checks for each extension using `az vm extension show` and only runs `terraform import` when the extension is present, preventing spurious failures.

> **Note:** Microsoft has not published a Dependency Agent build for Ubuntu 24.04 LTS yet. Leave `enable_dependency_agent_extension = false` (default) unless you're deploying on a supported distro and explicitly need Service Map.

After the imports succeed, re-run `terraform plan` and the extensions will be treated as managed resources going forward.

## Verify monitoring, logs, and backups

Once `terraform apply` completes, use the following checks to confirm everything is wired up:

1. **Azure Monitor Agent health & DCR association**
   - Portal: go to the VM → **Extensions + applications** and ensure *AzureMonitorLinuxAgent* reports *Provisioning succeeded*. If you enabled the optional Dependency Agent on a supported OS, it should also be green.
   - CLI: `az monitor data-collection rule association show --resource $VM_ID --name soundar-vm-dcr-assoc` should return `provisioningState = Succeeded`.

2. **Performance + Insights metrics stream (metrics-store)**
   - Run a quick KQL query in Log Analytics to confirm both `Microsoft-Perf` and `Microsoft-InsightsMetrics` streams are arriving:
     ```kusto
     InsightsMetrics
     | where Namespace == "Processor"
     | summarize avg(Val) by bin(TimeGenerated, 5m), Name
     | top 5 by TimeGenerated desc
     ```
   - In the Azure Portal, open **Monitor → Metrics → Custom** and scope it to the VM. If you select `InsightsMetrics` (Preview), CPU/Memory charts should populate automatically because the DCR now emits directly to Azure Monitor Metrics.

3. **Syslog and custom nginx/docker logs**
   - Use Log Analytics:
     ```kusto
     Syslog
     | where TimeGenerated > ago(1h)
     | project TimeGenerated, Computer, Facility, SeverityLevel, HostName, SyslogMessage
     ```
   - The nginx + container logs land in `CustomNginxAccessLogs_CL`. Tail them with:
     ```kusto
     CustomNginxAccessLogs_CL
     | take 20
     ```

4. **Recovery Services backups**
   - Portal: Recovery Services vault → **Backup items → Azure Virtual Machine** → select the VM to verify the last backup status and schedule.
   - CLI: `az backup job list --resource-group <rg> --vault-name <vault> --output table` shows recent jobs. A `Completed` entry should appear daily at the time defined by `vm_backup_daily_time`.

5. **Storage container for app backups**
   - Run `az storage container show --name app-backups --account-name <storage_account>` to verify it exists.
   - Upload a test artifact from the VM using the managed identity:
     ```bash
     az login --identity
     az storage blob upload --account-name <storage_account> --container-name app-backups --name smoke-test.txt --file smoke-test.txt --auth-mode login
     ```

Documenting the exact queries/commands makes it easier to hand off Day 2 monitoring to operations or to validate the environment after each pipeline run.

## Service principal setup

Create a tightly scoped service principal and capture its credentials for Terraform:

- **PowerShell:**
   ```powershell
   $subscriptionId = "07512706-3bc2-4200-9b89-5bce3249bddb"
   $sp = az ad sp create-for-rbac `
      --name "sp-soundar-rnd-01" `
      --role "Contributor" `
      --scopes "/subscriptions/$subscriptionId" `
      --sdk-auth | ConvertFrom-Json

   # Optional but recommended: allow role assignments for future automation
   az role assignment create `
      --assignee $sp.clientId `
      --role "User Access Administrator" `
      --scope "/subscriptions/$subscriptionId"
   ```

- **bash:**
   ```bash
   subscriptionId="07512706-3bc2-4200-9b89-5bce3249bddb"
   az ad sp create-for-rbac \
      --name "sp-soundar-rnd-01" \
      --role "Contributor" \
      --scopes "/subscriptions/${subscriptionId}" \
      --sdk-auth > sp-creds.json

   # Optional but recommended: allow role assignments for future automation
   appId=$(jq -r '.clientId' sp-creds.json)
   az role assignment create \
      --assignee ${appId} \
      --role "User Access Administrator" \
      --scope "/subscriptions/${subscriptionId}"
   ```

Record the following for Terraform:

- **clientId / appId** → `ARM_CLIENT_ID`
- **clientSecret / password** → `ARM_CLIENT_SECRET`
- **tenantId** → `ARM_TENANT_ID`
- **subscriptionId** → `ARM_SUBSCRIPTION_ID`

Export them before running Terraform:
- **PowerShell:**
   ```powershell
   $env:ARM_CLIENT_ID        = $sp.clientId
   $env:ARM_CLIENT_SECRET    = $sp.clientSecret
   $env:ARM_TENANT_ID        = $sp.tenantId
   $env:ARM_SUBSCRIPTION_ID  = $subscriptionId
   ```
- **bash:**
   ```bash
   export ARM_CLIENT_ID=$(jq -r '.clientId' sp-creds.json)
   export ARM_CLIENT_SECRET=$(jq -r '.clientSecret' sp-creds.json)
   export ARM_TENANT_ID=$(jq -r '.tenantId' sp-creds.json)
   export ARM_SUBSCRIPTION_ID=${subscriptionId}
   ```

These env vars allow the AzureRM provider to authenticate non-interactively.

## Customization highlights

- **VNet sizing:** change `vnet_address_space` and rewrite the `subnet_prefixes` map in your tfvars file.
- **NAT coverage:** `nat_subnet_names` controls which subnets route through the NAT gateway.
- **VM placement:** Update `vm_subnet_name`, `vm_size`, and `vm_os_disk_size_gb` to suit your workloads.
- **SSH exposure:** Port 22 is allowed only from inside the virtual network by default. If you need jump-box style access, introduce a bastion host or VPN instead of opening the NSG.
- **VM bootstrap:** Edit `modules/compute/cloud-init.yaml.tpl` if you want to install additional packages or change service behavior. Terraform automatically base64-encodes this file and feeds it into the VM's `custom_data` field.
- **Tagging:** Use the `tags` map to attach owner/cost center metadata to every resource.
- **Monitoring & protection:** Override `log_analytics_workspace_name`, `data_collection_rule_name`, extension names, and backup/lock variables in your tfvars file to align with your naming standards or retention needs.
- **Key Vault access:** Set `key_vault_data_plane_assignee_object_id` (and optionally the role/principal type variables) to have Terraform grant the caller a Key Vault RBAC role such as `Key Vault Secrets Officer`.
- **Key Vault firewall:** Populate `key_vault_allowed_ip_rules` with trusted `/32` CIDRs for operators running Terraform outside the VNet so the deployment can reach Key Vault data-plane APIs without opening it to the internet.
- **Key Vault troubleshooting toggle:** Use `key_vault_default_action` to temporarily set the firewall `default_action` to `Allow` during troubleshooting. Always flip it back to `Deny` once Terraform runs from a trusted network.
- **Storage + managed identity:** Customize `storage_account_*` variables to control the S3-like blob storage and use the VM's system-assigned managed identity with RBAC (`Storage Blob Data Contributor`) for keyless uploads/downloads.
- **Disk encryption:** Toggle `vm_encryption_at_host_enabled` if you need to disable/enable host-based encryption.
- **Container Registry:** Override `acr_name`, `acr_sku`, and `acr_retention_days` to control the Premium ACR instance and adjust the retention policy.
- **Managed identity role bindings:** `assign_vm_identity_key_vault_access` and `vm_key_vault_role_definition_name` let you decide whether the VM's managed identity gets Key Vault RBAC (for secrets/certs) automatically.
- **Service Map / Dependency Agent:** Toggle `enable_dependency_agent_extension` when you need VM Insights maps on a distro that Microsoft supports; leave it `false` (default) on Ubuntu 24.04+ to avoid extension failures.
- **Resource locks:** `vm_delete_lock_name`, `storage_account_delete_lock_name`, `acr_delete_lock_name`, and `app_gateway_delete_lock_name` control the CanNotDelete locks that protect critical resources from accidental removal.

## Using the VM's managed identity

Once the VM is provisioned, you can rely on its system-assigned managed identity to interact with Azure services without running `az login` or storing credentials:

### Azure Blob Storage (application backups)

```bash
az login --identity                             # runs under the VM's identity
az storage blob upload \
   --account-name <storage_account_name> \
   --container-name <storage_account_container_name> \
   --name backup.tar.gz \
   --file backup.tar.gz \
   --auth-mode login
```

### Azure Container Registry (push/pull images)

```bash
az login --identity
az acr login --name <acr_name>
docker build -t <acr_login_server>/myapp:latest .
docker push <acr_login_server>/myapp:latest
```

Terraform grants the VM `AcrPush`, so both push and pull succeed without admin credentials.

### Azure Key Vault (secrets + certificates)

If `assign_vm_identity_key_vault_access` is true (default), the VM identity receives the RBAC role defined by `vm_key_vault_role_definition_name`. Inside the VM you can run:

```bash
az login --identity
az keyvault secret show --vault-name <key_vault_name> --name my-secret
az keyvault certificate import --vault-name <key_vault_name> --name dev-cert --file cert.pfx --password "pass"
```

This eliminates the need for user-context `az login` when the VM itself needs to interact with Key Vault.

## Outputs

- `virtual_network_id`, `subnet_ids`, and `nat_public_ip` for downstream modules.
- `vm_private_ip`, `vm_admin_username`, `vm_admin_password` (sensitive) for operational use.

## Post-deploy checklist

1. Add the VM's subnet to any private DNS or monitoring solutions as needed.
2. Rotate the generated password after first login or replace it with an SSH key pair for improved security.
3. Consider storing the Terraform state in a remote backend (Azure Storage) for team collaboration.
4. Configure the `ARM_CLIENT_ID`, `ARM_CLIENT_SECRET`, `ARM_TENANT_ID`, and `ARM_SUBSCRIPTION_ID` environment variables (or use `az login`) before running Terraform so the AzureRM provider can authenticate.

## 🔧 Azure CLI operational cookbook

Use this section as a quick-reference when performing day-2 activities (registering preview features, administering Key Vault, or uploading certificates). Every example includes a representative output snippet so it is easy to recognize a successful run.

### Install Azure CLI on Ubuntu

```bash
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```

✅ **Sample output (truncated):**

```
Installing the Azure CLI...
Get:1 https://packages.microsoft.com/repos/azure-cli focal/main amd64 azure-cli 2.66.0-1~focal (123 MB)
Setting up azure-cli (2.66.0-1~focal)...
Azure CLI is installed. Run 'az --version' to confirm.
```

### Register the EncryptionAtHost feature

```bash
az feature register --namespace Microsoft.Compute --name EncryptionAtHost
```

Registration can take several minutes. Check the status until it reads **Registered**:

```bash
az feature show --namespace Microsoft.Compute --name EncryptionAtHost
```

✅ **Sample output:**

```
{
   "id": "/subscriptions/<subscription-id>/providers/Microsoft.Features/providers/Microsoft.Compute/features/EncryptionAtHost",
   "name": "Microsoft.Compute/EncryptionAtHost",
   "properties": {
      "state": "Registered"
   },
   "type": "Microsoft.Features/providers/features"
}
```

Once registered, run `az provider register --namespace Microsoft.Compute` so the subscription picks up the change.

### Explore Key Vault inventory

List every Key Vault in the current subscription:

```bash
az keyvault list --output table
```

✅ **Sample output:**

```
Name                ResourceGroup     Location    EnabledForDeployment
------------------  ----------------  ----------  --------------------
soundar-kv-dev-08   soundar-rnd-08    eastus      True
soundar-kv-rnd-08   soundar-rnd-08    eastus      False
```

Show the properties of a single vault:

```bash
az keyvault show -n soundar-kv-dev-08 -g soundar-rnd-08 --output table
```

✅ **Sample output:**

```
Name              ResourceGroup   Location    SKU   EnabledForDeployment  VaultUri
----------------  --------------  ----------  ----  --------------------  ---------------------------------------------
soundar-kv-dev-08 soundar-rnd-08  eastus      standard  True              https://soundar-kv-dev-08.vault.azure.net/
```

### Grant Key Vault RBAC access to the current Azure CLI user

1. Capture your AAD object id:

    ```bash
    myObjectId=$(az ad signed-in-user show --query id -o tsv)
    ```

2. Assign a role (for example `Key Vault Administrator`) on the vault scope:

    ```bash
    az role assignment create \
       --assignee-object-id ${myObjectId} \
       --assignee-principal-type User \
       --role "Key Vault Administrator" \
       --scope "/subscriptions/<subscription-id>/resourceGroups/soundar-rnd-08/providers/Microsoft.KeyVault/vaults/soundar-kv-dev-08"
    ```

✅ **Sample output:**

```
{
   "id": "/subscriptions/<subscription-id>/providers/Microsoft.Authorization/roleAssignments/8b16...",
   "name": "8b16...",
   "principalName": "soundararajan@contoso.com",
   "principalType": "User",
   "roleDefinitionName": "Key Vault Administrator",
   "scope": "/subscriptions/<subscription-id>/resourceGroups/soundar-rnd-08/providers/Microsoft.KeyVault/vaults/soundar-kv-dev-08"
}
```

### Convert Let’s Encrypt certificates to PFX

Use `openssl pkcs12 -export` to bundle a certificate and private key into a password-protected PFX file:

```bash
openssl pkcs12 -export \
   -in /etc/letsencrypt/live/<domain>/fullchain.pem \
   -inkey /etc/letsencrypt/live/<domain>/privkey.pem \
   -passout pass:<strong-random-password> \
   -out <output-file>.pfx
```

✅ **Sample output:**

```
Enter Export Password:
Verifying - Enter Export Password:
MAC verified OK
```

### Upload certificates and secrets to Key Vault

Import the PFX into a Key Vault certificate object:

```bash
az keyvault certificate import \
   --vault-name soundar-kv-rnd-08-01 \
   --name dev-test-ssl \
   --file dev-test-app-gateway.pfx \
   --password "certpass123"
```

✅ **Sample output:**

```
{
   "id": "https://soundar-kv-rnd-08-01.vault.azure.net/certificates/dev-test-ssl/2f3d...",
   "status": "completed",
   "x509ThumbprintHex": "97E5..."
}
```

Store an arbitrary file as a Base64-encoded secret:

```bash
az keyvault secret set \
   --vault-name soundar-kv-dev-08 \
   --name "my-file-secret" \
   --file secret1.txt \
   --encoding base64 \
   --content-type "application/octet-stream" \
   --tags source=cli env=dev
```

✅ **Sample output:**

```
{
   "id": "https://soundar-kv-dev-08.vault.azure.net/secrets/my-file-secret/6931...",
   "attributes": {
      "enabled": true,
      "created": "2025-01-12T14:05:24+00:00"
   },
   "tags": {
      "env": "dev",
      "source": "cli"
   }
}
```

### When to use `az login --identity`

Run `az login --identity` **only on an Azure resource that has a system-assigned or user-assigned managed identity** (for example, the VM deployed by this Terraform stack). This command fetches a token for that managed identity, allowing scripts to call Azure services (Key Vault, Storage, ACR, etc.) without storing user credentials. Do **not** run it from your developer workstation—it will fail because the local machine does not have a managed identity. Use regular `az login` there instead.
