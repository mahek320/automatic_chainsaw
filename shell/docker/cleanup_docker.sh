#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'EOF'
Usage: cleanup_docker.sh [--dry-run] [--force] [--skip-build-cache]

Safely prunes dangling Docker containers, images, volumes, and build cache to free local disk space.

Options:
  --dry-run            Print the commands that would run without deleting anything.
  --force              Skip the interactive confirmation prompt.
  --skip-build-cache   Do not prune Docker builder cache layers.
  -h, --help           Display this help message and exit.
EOF
}

DRY_RUN=false
FORCE_CONFIRMATION=false
SKIP_BUILD_CACHE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --force)
      FORCE_CONFIRMATION=true
      shift
      ;;
    --skip-build-cache)
      SKIP_BUILD_CACHE=true
      shift
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      show_help
      exit 1
      ;;
  esac
done

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker CLI not found in PATH. Install Docker before running this script." >&2
  exit 1
fi

log() {
  echo "[docker-cleanup] $*"
}

run_cmd() {
  if $DRY_RUN; then
    log "[dry-run] $*"
  else
    "$@"
  fi
}

if ! $DRY_RUN && ! $FORCE_CONFIRMATION; then
  read -r -p "This will permanently delete unused Docker artifacts. Continue? [y/N] " reply
  case "$reply" in
    [yY][eE][sS]|[yY])
      ;;
    *)
      log "Aborted by user."
      exit 0
      ;;
  esac
fi

if ! $DRY_RUN; then
  log "Disk usage before cleanup:"
  docker system df || true
fi

log "Removing stopped containers..."
run_cmd docker container prune --force

log "Removing dangling images..."
run_cmd docker image prune --force

log "Removing unused images (no containers reference them)..."
run_cmd docker image prune --all --force

log "Removing unused volumes..."
run_cmd docker volume prune --force

if ! $SKIP_BUILD_CACHE; then
  log "Removing build cache (buildx)..."
  run_cmd docker builder prune --all --force
else
  log "Skipping build cache prune."
fi

if ! $DRY_RUN; then
  log "Disk usage after cleanup:"
  docker system df || true
fi

log "Docker cleanup completed."
