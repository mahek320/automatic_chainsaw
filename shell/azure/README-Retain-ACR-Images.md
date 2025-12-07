# Maintenance Scripts

## retain_acr_images.sh

Trims Azure Container Registry repositories so only the newest N tags remain. Useful when you deploy sporadically and time-based retention would remove recent builds.

### Requirements
- Azure CLI (`az`) installed.
- Logged in (`az login`) with permissions to read and delete repository tags.

### Usage
```bash
./retain_acr_images.sh --registry myregistry --repository myapp --keep 7
```
Options:
- `--registry/-r`: ACR name (e.g., `contoso` in `contoso.azurecr.io`).
- `--repository/-p`: Repository/image name inside the registry.
- `--keep/-k`: Number of newest tags to keep (default 7).
- `--dry-run`: Show which tags would be removed without deleting them.

Schedule this via cron or [ACR Tasks](https://learn.microsoft.com/azure/container-registry/container-registry-tasks-overview) to enforce retention automatically.

## cleanup_docker.sh

Frees disk space on local builders by pruning stopped containers, dangling/unused images, anonymous volumes, and optional build cache layers.

### Usage
```bash
./cleanup_docker.sh --force
```
Flags:
- `--dry-run`: Preview actions only.
- `--force`: Skip the confirmation prompt (handy for automation).
- `--skip-build-cache`: Leave builder cache untouched if you rely on it for faster rebuilds.

Both scripts emit `[acr-retain]` / `[docker-cleanup]` prefixed log lines so you can safely run them in CI logs.
