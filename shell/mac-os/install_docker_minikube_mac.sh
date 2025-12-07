#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
macOS (Apple Silicon) container tooling bootstrapper.

Usage:
  install_docker_minikube_mac.sh [--start]

Options:
  --start   Launch Docker Desktop and start a minikube cluster after installs.
  --help    Show this help message.
EOF
}

START_CLUSTER=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --start)
      START_CLUSTER=true
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "[setup] Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ $(uname -s) != "Darwin" ]]; then
  echo "[setup] This script only supports macOS." >&2
  exit 1
fi

if [[ $(uname -m) != "arm64" ]]; then
  echo "[setup] Warning: Script was validated on Apple Silicon (arm64)." >&2
fi

ensure_homebrew() {
  if command -v brew >/dev/null 2>&1; then
    return
  fi

  echo "[setup] Homebrew not detected. Installing via official script (may prompt for sudo)..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [[ -x "$candidate" ]]; then
      eval "$("$candidate" shellenv)"
      break
    fi
  done

  if ! command -v brew >/dev/null 2>&1; then
    echo "[setup] Unable to find Homebrew after installation. Please add it to your PATH and rerun." >&2
    exit 1
  fi

  echo "[setup] Homebrew installed. Consider adding 'eval \"$(brew shellenv)\"' to your shell profile."
}

ensure_homebrew

echo "[setup] Updating Homebrew formulas..."
brew update >/dev/null

ensure_formula() {
  local formula="$1"
  if brew list "$formula" >/dev/null 2>&1; then
    echo "[setup] $formula already installed."
  else
    echo "[setup] Installing $formula..."
    brew install "$formula"
  fi
}

ensure_cask() {
  local cask="$1"
  if brew list --cask "$cask" >/dev/null 2>&1; then
    echo "[setup] $cask already installed."
  else
    echo "[setup] Installing $cask..."
    brew install --cask "$cask"
  fi
}

FORMULAS=(
  docker-compose
  minikube
  kubectl
  python@3.11
  nginx
  git
  gh
  azure-cli
  terraform
  helm
  k9s
  curl
  wget
  openssl
  jq
  nmap
  netcat
  node
)

for formula in "${FORMULAS[@]}"; do
  ensure_formula "$formula"
done

CASKS=(
  docker
  visual-studio-code
)

for cask in "${CASKS[@]}"; do
  ensure_cask "$cask"
done

setup_python_tooling() {
  local python_bin
  python_bin="$(brew --prefix python@3.11)/bin/python3.11"

  echo "[setup] Configuring Python 3.11 toolchain..."
  "$python_bin" -m ensurepip --upgrade >/dev/null
  "$python_bin" -m pip install --upgrade pip >/dev/null
  "$python_bin" -m pip install --upgrade virtualenv >/dev/null

  mkdir -p "$HOME/venvs"
  local venv_path="$HOME/venvs/azure-ai-tools"
  if [[ ! -d "$venv_path" ]]; then
    "$python_bin" -m venv "$venv_path"
    echo "[setup] Created Python virtual environment at $venv_path"
  else
    echo "[setup] Reusing existing virtual environment at $venv_path"
  fi
}

setup_python_tooling

configure_azure_ai_extensions() {
  if ! command -v az >/dev/null 2>&1; then
    echo "[setup] Azure CLI missing; skipping AI extension configuration." >&2
    return
  fi

  az config set extension.use_dynamic_install=yes_without_prompt >/dev/null
  local extensions=(openai cognitiveservices)
  for ext in "${extensions[@]}"; do
    if az extension show --name "$ext" >/dev/null 2>&1; then
      az extension update --name "$ext" >/dev/null
    else
      az extension add --name "$ext" >/dev/null
    fi
    echo "[setup] Azure CLI extension '$ext' ready for use."
  done
}

configure_azure_ai_extensions

echo "[setup] Docker CLI version: $(docker --version 2>/dev/null || echo 'Docker not running yet')"
echo "[setup] Docker Compose version: $(docker compose version 2>/dev/null || docker-compose version 2>/dev/null || echo 'Docker not running yet')"
echo "[setup] Minikube version: $(minikube version | head -n 1)"
echo "[setup] Python version: $($(brew --prefix python@3.11)/bin/python3.11 --version)"
echo "[setup] Node version: $(node -v 2>/dev/null || echo 'node not initialized') | npm $(npm -v 2>/dev/null || echo 'missing')"
echo "[setup] Azure CLI version: $(az version --query cliCoreVersion -o tsv 2>/dev/null || echo 'login required')"
echo "[setup] Terraform version: $(terraform version | head -n 1)"
echo "[setup] Helm version: $(helm version --short 2>/dev/null || echo 'helm not initialized')"
echo "[setup] k9s version: $(k9s version --short 2>/dev/null || echo 'k9s pending')"

if [[ "$START_CLUSTER" == true ]]; then
  echo "[setup] Launching Docker Desktop..."
  open -g -a Docker
  echo -n "[setup] Waiting for Docker engine to be ready"
  until docker info >/dev/null 2>&1; do
    echo -n "."
    sleep 2
  done
  echo " ready."

  echo "[setup] Starting minikube with Docker driver..."
  minikube start --driver=docker --cpus=4 --memory=4096 --disk-size=20g
fi

echo "[setup] Finished. Launch Docker Desktop from Applications, then run 'minikube start --driver=docker' when ready."
