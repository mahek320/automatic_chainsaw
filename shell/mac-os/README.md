# macOS Container Environment Setup

This automation bootstraps a full Azure/Kubernetes developer workstation on macOS Apple Silicon (M3 tested). It now covers Docker Desktop, Kubernetes tooling, Azure CLI with AI extensions, Terraform, Node.js LTS, VS Code, networking tools, and a ready-to-use Python 3.11 virtual environment.

## install_docker_minikube_mac.sh

### Prerequisites
- macOS Sonoma (or newer) on Apple Silicon with admin rights
- Internet connectivity (Homebrew auto-installs if missing)

### Usage
```bash
chmod +x scripts/install_docker_minikube_mac.sh
./scripts/install_docker_minikube_mac.sh          # Install all tooling
./scripts/install_docker_minikube_mac.sh --start  # Install + launch Docker Desktop + start Minikube
```

### Installed tooling (high level)
- **Containers/Kubernetes:** Docker Desktop (cask), Docker Compose CLI, kubectl, Minikube (optional auto-start)
- **Azure & Infra:** Azure CLI + `openai` and `cognitiveservices` extensions, Terraform, Helm, k9s
- **Languages & Dev:** Python 3.11 + pip + virtualenv + `~/venvs/azure-ai-tools`, Node.js LTS (`node` + `npm`), Git, GitHub CLI, Visual Studio Code
- **Ops & networking:** nginx, curl, wget, openssl, jq, nmap, netcat

### Python virtual environment
The script provisions a reusable venv: `~/venvs/azure-ai-tools`.

```bash
source ~/venvs/azure-ai-tools/bin/activate
python -m pip install <package>
deactivate
```

Visual Studio Code installs via the Homebrew cask, so the app bundle lands in `/Applications/Visual Studio Code.app` just like a manual download.

### Azure AI CLI commands
Azure CLI is installed (or upgraded) via Homebrew, and the script runs:

```bash
az config set extension.use_dynamic_install=yes_without_prompt
az extension add --name openai
az extension add --name cognitiveservices
```

After signing in (`az login`), you can manage Azure AI surfaces:

```bash
az cognitiveservices account list
az cognitiveservices account keys list -g <rg> -n <account>
az cognitiveservices account identity assign -g <rg> -n <account>

az openai account list
az openai deployment list -g <rg> -a <openai_account>
```

### Starting Docker and Minikube Manually
1. Launch Docker Desktop from Applications (or `open -a Docker`) and wait for "Docker Desktop is running".
2. Start Minikube with the Docker driver:
   ```bash
   minikube start --driver=docker --cpus=4 --memory=4096 --disk-size=20g
   ```
3. Verify Kubernetes access:
   ```bash
   kubectl config use-context minikube
   kubectl get nodes
   ```
4. Helpful helpers: `minikube dashboard`, `minikube tunnel`, `k9s`.

### Troubleshooting
- If prompted for sudo during Homebrew cask installs, accept (Docker Desktop/VS Code). After installation, add `eval "$(/opt/homebrew/bin/brew shellenv)"` to your shell profile if Brew is not on PATH.
- Re-run the script anytime; it is idempotent and will upgrade existing formulas/casks.
- If Docker never becomes ready, quit and relaunch Docker Desktop and ensure virtualization is enabled.
- Reset Minikube via `minikube delete` before re-running with `--start`.
- For Azure CLI issues, run `az login` and `az account show` to confirm tokens, then re-run the AI commands above.
