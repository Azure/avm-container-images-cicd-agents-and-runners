# Linux GitHub Runner Docker Image for Azure Container Instances

> Note: You can update the [Dockerfile](Dockerfile) to add any software that your require into the Azure DevOps agent, if you don't want to have to download the bits during all pipelines executions.

## Environment Variables

`GH_RUNNER_TOKEN`: The token used to authenticate the runner with GitHub. This can be a PAT or a self-hosted runner token. If supplying a self-hosted runner token, be aware that the token will expire after a few hours, so will only work with persistent runners. Mutually exclusive with `GH_RUNNER_APP_ID`/`GH_RUNNER_APP_PRIVATE_KEY`.
`GH_RUNNER_URL`: The URL of the GitHub repository or organization (e.g. https://github.com/my-org or https://github.com/my-org/my-repo).
`GH_RUNNER_API_URL`: Optional. Override for the GitHub REST API base URL. Defaults to `https://api.github.com` for github.com, `https://api.<domain>` for `*.ghe.com`.
`GH_RUNNER_NAME`: The name of the runner as it appears in GitHub.
`GH_RUNNER_GROUP`: Optional. If not supplied, the runner will be added to the default group. This requires Enterprise licening.
`GH_RUNNER_MODE`: Supported values are `ephemeral` and `persistent`. Default is `ephemeral` if the env var is not supplied.
`GH_RUNNER_APP_ID`: Optional. The GitHub App ID. When supplied together with `GH_RUNNER_APP_PRIVATE_KEY`, the container will mint a JWT, exchange it for an installation access token, and use that to request a runner registration token. Mutually exclusive with `GH_RUNNER_TOKEN`.
`GH_RUNNER_APP_PRIVATE_KEY`: Optional. The PEM-encoded private key of the GitHub App. Required when `GH_RUNNER_APP_ID` is set. Newlines may be supplied either literally or escaped as `\n`.
`GH_RUNNER_APP_LOGIN`: Optional. The login (org or repo owner) the GitHub App is installed against. Defaults to the org name (or repo owner) parsed from `GH_RUNNER_URL`.

## Build it

```bash
docker build -t YOUR_IMAGE_NAME:YOUR_IMAGE_TAG .
```

## Push it

```bash
docker push YOUR_IMAGE_NAME:YOUR_IMAGE_TAG
```
