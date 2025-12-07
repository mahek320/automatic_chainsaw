# GitHub Action: Azure Artifacts Package Deployment

This repository includes a reusable GitHub Actions workflow that publishes a Node.js package to Azure Artifacts and (optionally) prepares Python packages for upload. Run it manually to push signed artifacts into your Azure DevOps feed.

## Workflow location
- File: `.github/workflows/azure-artifacts-deploy.yml`

## Triggers & inputs
The workflow is manually triggered via **Run workflow** (`workflow_dispatch`) and prompts for:
- `branch_name` (text, default `main`): Git branch to check out.
- `environment` (choice: `development` or `production`): Controls the GitHub Environment for approvals/secrets.

## Permissions & runners
- Requires a self-hosted runner (or any runner with equivalent tooling) that provides Node.js, npm, Python, and twine.
- Workflow-level permissions: `contents: read`, `id-token: write`, `actions: read`.

## Secrets
- `AZURE_ARTIFACT_PAT`: Azure DevOps Personal Access Token scoped to the target feed (Packaging: Read & Write). Injected during the publish step.

## Key steps
1. **Checkout** the specified branch from the repository hosting the workflow (or override via `workflow_dispatch`).
2. **Stamp build version** using the current timestamp; stored in the `VERSION` environment variable for later steps.
3. **NPM Publish**
   - Navigates to `my-node-package/`
   - Replaces the placeholder token in `.npmrc`
   - Runs `npm publish`
   - Packs a tgz artifact (`npm pack my-node-package@1.0.0`) against your Azure Artifacts npm registry (e.g., `https://pkgs.dev.azure.com/<org>/<project>/_packaging/<feed-name>/npm/registry/`).
   - Emits a digest output for downstream jobs
4. **(Optional) Twine upload** block is scaffolded but disabled via `if: false`. Toggle to `true` when Python packaging support is ready.
5. **Scan placeholder** currently emits a stub output. Replace with a real SCA/SAST step (e.g., `trivy`, `npm audit`) as needed.

## Outputs
- `image-digest`: SHA-256 of the `.tgz` produced by `npm pack`.
- `scan-results`: Placeholder string from the scan step.

## Versioning
A timestamp-based version (`YYYY-MM-DD-HH-MM`) is exported through `$VERSION`. Downstream scripts can tag images or packages using this variable.

## Extending the workflow
- Swap out `my-node-package` for your package directory and version.
- Enable the Twine step for Python artifacts.
- Replace the scan placeholder with your preferred security scanner.
- Add notifications (Teams/Slack) once publishing succeeds.

## Troubleshooting
- Ensure the runner has network access to `pkgs.dev.azure.com`.
- Check `.npmrc` after token substitution if authentication fails.
- If `npm publish` complains about existing versions, bump the package version in `package.json` before rerunning.
