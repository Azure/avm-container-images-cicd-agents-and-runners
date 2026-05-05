# Linux Azure DevOps Agent Docker Image for Azure Container Instances

IMPORTANT: This code is completely stolen from https://github.com/Azure/terraform-azurerm-aci-devops-agent

This image is based on the [official documentation](https://docs.microsoft.com/en-us/azure/devops/pipelines/agents/docker?view=azure-devops#linux).

> Note: You can update the [Dockerfile](Dockerfile) to add any software that your require into the Azure DevOps agent, if you don't want to have to download the bits during all pipelines executions.

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
- Automatic token management by Azure platform

## Environment Variables

### Common Variables (Required for both authentication methods)

- `AZP_URL`: The URL of the Azure DevOps organization
- `AZP_POOL`: The name of the agent pool
- `AZP_AGENT_NAME`: The name of the agent

### PAT Authentication Variables

- `AZP_TOKEN`: The Personal Access Token used to authenticate with Azure DevOps. Requires relevant scopes and long expiration date

### UAMI Authentication Variables

- `USRMI_ID`: The client ID of the User Assigned Managed Identity assigned to the Azure Container Instance. When set, the container will log in with the managed identity and obtain an Azure DevOps access token automatically; `AZP_TOKEN` is not required.

> **Note**: To use UAMI authentication you must:
> 1. Assign a User Assigned Managed Identity to the Azure Container Instance.
> 2. Add the managed identity as a user in your Azure DevOps organization.
> 3. Grant it the required permissions on the agent pool (e.g. Administrator at the organization-level pool security so the agent can register).

## Usage Examples

### Using with PAT Authentication (Traditional)

```bash
docker run -e AZP_URL=https://dev.azure.com/myorg \
           -e AZP_TOKEN=your-pat-token \
           -e AZP_POOL=my-agent-pool \
           -e AZP_AGENT_NAME=myagent \
           YOUR_IMAGE_NAME:YOUR_IMAGE_TAG
```

### Using with UAMI Authentication (Recommended)

```bash
# When deployed in Azure Container Instances with a user assigned managed identity
docker run -e AZP_URL=https://dev.azure.com/myorg \
           -e AZP_POOL=my-agent-pool \
           -e AZP_AGENT_NAME=myagent \
           -e USRMI_ID=<client-id-of-user-assigned-managed-identity> \
           YOUR_IMAGE_NAME:YOUR_IMAGE_TAG
```

## Build it

```bash
docker build -t YOUR_IMAGE_NAME:YOUR_IMAGE_TAG .
```

## Push it

```bash
docker push YOUR_IMAGE_NAME:YOUR_IMAGE_TAG
```
