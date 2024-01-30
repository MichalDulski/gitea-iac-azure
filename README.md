# Prerequisites

Before deploying Gitea using Terraform, ensure you have completed the following prerequisites:

1. **Install Azure CLI**: Download and install the Azure CLI tool.
2. **Install Terraform**: Download and install Terraform.
3. **Login to Azure**:
    ```bash
    az login
    ```
4. **Set the Azure Subscription**:
    Use the Azure CLI to set the active subscription.
    ```bash
    az account set --subscription "<YOUR_SUBSCRIPTION_ID>"
    ```
5. **Create an Azure Service Principal**:
    This service principal is used by Terraform to manage Azure resources.
    ```bash
    az ad sp create-for-rbac --role="Contributor" --scopes="/subscriptions/<YOUR_SUBSCRIPTION_ID>"
    ```
    Replace `<YOUR_SUBSCRIPTION_ID>` with your actual Azure subscription ID.
6. **Set Environment Variables**:
    Configure your shell environment with Azure credentials.
    ```bash
    export ARM_CLIENT_ID="<SERVICE_PRINCIPAL_APPID>"
    export ARM_CLIENT_SECRET="<SERVICE_PRINCIPAL_PASSWORD>"
    export ARM_SUBSCRIPTION_ID="<YOUR_SUBSCRIPTION_ID>"
    export ARM_TENANT_ID="<TENANT_ID>"
    ```
    Replace the placeholders with the values obtained from the service principal creation step.

# Deployment Steps

Once you have met all the prerequisites, follow these steps to deploy Gitea:

1. **Run the Deployment Script**:
    Execute the `deploy-gitea.sh` script to

