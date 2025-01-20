# GitHub to Port Exporter Action

The **GitHub to Port Exporter** composite action fetches and synchronizes GitHub metadata (Code Scanning Alerts, Dependabot Alerts, and Dependencies) with the [Port](https://getport.io/) platform. This action supports seamless integration between GitHub repositories and Port, enabling you to visualize and manage your application's metadata effectively.


## Features

- Fetches **Code Scanning Alerts** from GitHub repositories.
- Fetches **Dependabot Alerts** for dependency vulnerabilities.
- Generates a Software Bill of Materials (SBOM) for project dependencies.
- Maps and transforms GitHub metadata into Port-compatible JSON entities.
- Uploads transformed metadata to Port.
- Updates Port applications with the latest container images.

## Inputs

| Input Name         | Required | Description                                                                               |
|--------------------|----------|-------------------------------------------------------------------------------------------|
| `version`          | `true`   | The version tag used to filter and fetch metadata from GitHub (e.g., `v1.0.0`).          |
| `githubToken`      | `true`   | GitHub token with access to the repository.                                               |
| `portClientId`     | `true`   | Port API client ID for authentication.                                                    |
| `portClientSecret` | `true`   | Port API client secret for authentication.                                                |
| `application`      | `true`   | The name of the application in Port to associate the exported data.                       |


## Outputs

| Output Name | Description                                       |
|-------------|---------------------------------------------------|
| `success`   | Indicates whether the export operation completed successfully (`true` or `false`). |


## Example Usage

```yaml
name: Export GitHub Metadata to Port
on:
  push:
    branches:
      - main

jobs:
  export-metadata:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout Repository
        uses: actions/checkout@v4

      - name: Export GitHub Metadata to Port
        uses: ./ # Modify to where this action is hosted
        with:
          version: "v1.0.0"
          githubToken: "${{ secrets.GITHUB_TOKEN }}"
          portClientId: "${{ secrets.PORT_CLIENT_ID }}"
          portClientSecret: "${{ secrets.PORT_CLIENT_SECRET }}"
          application: "my-application"
```

## How It Works

1. **Setup**:
   - The action sets up the necessary script paths and environment variables.

2. **Validation**:
   - Ensures all required inputs are provided.

3. **Fetch Metadata**:
   - Retrieves Code Scanning Alerts, Dependabot Alerts, and SBOM data from GitHub.

4. **Transform Data**:
   - Converts raw GitHub metadata into Port-compatible JSON entities.

5. **Upload to Port**:
   - Authenticates with Port and uploads the transformed entities.

6. **Update Port Application**:
   - Links the exported data to the specified Port application and updates container images.

## Debugging and Logs

- To debug issues, check the logs for intermediate steps.
- All JSON artifacts are archived using the [actions/upload-artifact](https://github.com/actions/upload-artifact) action for inspection.

## Requirements

- The following tools must be available in the environment:
  - `bash`
  - `jq` (for JSON processing)

You can check and install prerequisites using the `check-dependencies.sh` script.

## Troubleshooting

### Common Issues
1. **Invalid Credentials**:
   - Ensure `portClientId` and `portClientSecret` are valid and correspond to your Port account.

2. **GitHub API Rate Limits**:
   - If you encounter rate-limiting errors, verify your `githubToken` has adequate permissions.

3. **Data Upload Failures**:
   - Review the error logs for details about failed uploads.

### Intermediate Artifacts
- JSON files for Code Scanning Alerts, Dependabot Alerts, and SBOM data are archived for review if uploads fail.


## Contributions

Contributions, issues, and feature requests are welcome! Feel free to open an issue or a pull request.

## References

- [GitHub Code Scanning Alerts API](https://docs.github.com/en/rest/code-scanning)
- [GitHub Dependabot Alerts API](https://docs.github.com/en/rest/dependabot)
- [Port Platform](https://getport.io/)