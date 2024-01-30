# Pre-requisites

1. Install Azure CLI
2. Install Terraform
3. Login into Azure
    ```bash
    az login
    ```
4. Set the account subscription with the Azure CLI
    ```bash
    az account set --subscription "35akss-subscription-id"
    ```
5. Create Azure Service Principal
    ```bash
    az ad sp create-for-rbac --role="Contributor" --scopes="/subscriptions/<SUBSCRIPTION_ID>"
    ```
6. Set environmental variables
    ```bash
    export ARM_CLIENT_ID="<APPID_VALUE>"
    export ARM_CLIENT_SECRET="<PASSWORD_VALUE>"
    export ARM_SUBSCRIPTION_ID="<SUBSCRIPTION_ID>"
    export ARM_TENANT_ID="<TENANT_VALUE>"
    ```
7. Run deploy-gitea.sh script
    ```bash
    ./deploy-gitea.sh
    ```
