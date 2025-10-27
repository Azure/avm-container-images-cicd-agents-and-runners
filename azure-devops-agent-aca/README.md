# Linux Azure DevOps Agent Docker Image for Azure Container Apps

> Note: You can update the [Dockerfile](dockerfile) to add any software that your require into the Azure DevOps Agent, if you don't want to have to download the bits during all pipelines executions.

This docker image is used as a basic image for the Azure Verified Module to run Azure DevOps Agents in Azure Container Apps with support for both **Personal Access Token (PAT)** and **User Assigned Managed Identity (UAMI)** authentication methods.

## Authentication Methods

This container image supports two authentication methods:

### 🔐 Personal Access Token (PAT) - Traditional Method
- Uses `AZP_TOKEN` environment variable
- Requires token management and rotation
- Suitable for development and testing scenarios

### 🛡️ User Assigned Managed Identity (UAMI) - Recommended ⭐
- **Zero secrets**: No PAT tokens required
- Uses Azure AD identity for authentication
- Enhanced security for production workloads
- Supports KEDA auto-scaling with managed identity
- Automatic token management by Azure platform

## Credits

The original Dockerfile and shell scripts are derived from [Microsoft Learn](https://learn.microsoft.com/en-us/azure/devops/pipelines/agents/docker?view=azure-devops#linux).

## Environment Variables

### Common Variables (Required for both authentication methods)

- `AZP_URL`: The URL of the Azure DevOps organization
- `AZP_POOL`: The name of the agent pool
- `AZP_AGENT_NAME`: The name of the agent
- `AZP_AGENT_NAME_PREFIX`: The prefix for the agent name. Overrides `AZP_AGENT_NAME`
- `AZP_RANDOM_AGENT_SUFFIX`: Whether to add a random string to the `AZP_AGENT_NAME_PREFIX` to create a unique agent name. Default is `true`

### PAT Authentication Variables

- `AZP_TOKEN`: The Personal Access Token used to authenticate with Azure DevOps. Requires relevant scopes and long expiration date

### UAMI Authentication Variables

- `AZURE_CLIENT_ID`: The client ID of the User Assigned Managed Identity (automatically provided in Azure Container Apps)
- `AZURE_TENANT_ID`: The Azure AD tenant ID (automatically provided in Azure Container Apps)
- `AZURE_FEDERATED_TOKEN_FILE`: Path to the federated token file (automatically provided in Azure Container Apps)
- `USE_MANAGED_IDENTITY`: Set to `true` to enable UAMI authentication instead of PAT

> **Note**: When using UAMI authentication, the `AZP_TOKEN` variable is not required. The container will automatically use the managed identity for authentication.

## Usage Examples

### Using with PAT Authentication (Traditional)

```bash
docker run -e AZP_URL=https://dev.azure.com/myorg \
           -e AZP_TOKEN=your-pat-token \
           -e AZP_POOL=my-agent-pool \
           -e AZP_AGENT_NAME_PREFIX=myagent \
           YOUR_IMAGE_NAME:YOUR_IMAGE_TAG
```

### Using with UAMI Authentication (Recommended)

```bash
# When deployed in Azure Container Apps with managed identity
docker run -e AZP_URL=https://dev.azure.com/myorg \
           -e AZP_POOL=my-agent-pool \
           -e AZP_AGENT_NAME_PREFIX=myagent \
           -e USE_MANAGED_IDENTITY=true \
           YOUR_IMAGE_NAME:YOUR_IMAGE_TAG
```

> **Note**: UAMI authentication works seamlessly when deployed in Azure Container Apps with a User Assigned Managed Identity. The Azure platform automatically provides the necessary identity tokens.

## Build it

```bash
docker build -t YOUR_IMAGE_NAME:YOUR_IMAGE_TAG .
```

## Push it

```bash
docker push YOUR_IMAGE_NAME:YOUR_IMAGE_TAG
```
