#!/usr/bin/env bash
set -euo pipefail

KEEP=7
DRY_RUN=false
REGISTRY=""
REPOSITORY=""

usage() {
  cat <<'EOF'
Usage: retain_acr_images.sh --registry <name> --repository <repo> [--keep N] [--dry-run]

Keeps only the newest N tags in an Azure Container Registry repository. Older tags are deleted
via `az acr repository delete --image repo:tag`.

Options:
  -r, --registry     Azure Container Registry name (no FQDN, e.g., myregistry)
  -p, --repository   Repository name inside the registry
  -k, --keep         Number of newest tags to retain (default: 7)
  --dry-run          Print actions without deleting anything
  -h, --help         Show this help

Requirements:
  - Azure CLI (`az`) installed and logged in
  - Permissions to list and delete tags in the target registry
EOF
}

log() {
  echo "[acr-retain] $*"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -r|--registry)
      REGISTRY="$2"
      shift 2
      ;;
    -p|--repository)
      REPOSITORY="$2"
      shift 2
      ;;
    -k|--keep)
      KEEP="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$REGISTRY" || -z "$REPOSITORY" ]]; then
  echo "--registry and --repository are required." >&2
  usage
  exit 1
fi

if ! [[ "$KEEP" =~ ^[0-9]+$ ]] || [[ "$KEEP" -lt 1 ]]; then
  echo "--keep must be a positive integer" >&2
  exit 1
fi

if ! command -v az >/dev/null 2>&1; then
  echo "Azure CLI (az) not found in PATH." >&2
  exit 1
fi

log "Fetching tags for $REGISTRY/$REPOSITORY (keeping latest $KEEP)"
tags=$(az acr repository show-tags \
  --name "$REGISTRY" \
  --repository "$REPOSITORY" \
  --orderby time_desc \
  --output tsv)

if [[ -z "$tags" ]]; then
  log "No tags found. Nothing to prune."
  exit 0
fi

count=0
removed=0
while IFS= read -r tag; do
  [[ -z "$tag" ]] && continue
  count=$((count + 1))
  if [[ $count -le $KEEP ]]; then
    log "Keeping $REPOSITORY:$tag"
    continue
  fi
  if $DRY_RUN; then
    log "[dry-run] Would delete $REPOSITORY:$tag"
  else
    log "Deleting $REPOSITORY:$tag"
    az acr repository delete \
      --name "$REGISTRY" \
      --image "$REPOSITORY:$tag" \
      --yes \
      --output none
  fi
  removed=$((removed + 1))
done <<< "$tags"

if [[ $removed -eq 0 ]]; then
  log "No tags needed deletion."
else
  log "Removed $removed old tag(s)."
fi
