# GitHub Runner Requirements & Tool Installation Guide

This document outlines the tools and dependencies required for running the Azure Container App deployment workflows, including what's pre-installed on GitHub-hosted runners and what needs to be installed during workflow execution.

---

## 📋 Table of Contents

1. [GitHub-Hosted Runner Pre-installed Tools](#github-hosted-runner-pre-installed-tools)
2. [Self-Hosted Runner Requirements](#self-hosted-runner-requirements)
3. [Runtime Tool Installations](#runtime-tool-installations)
4. [Installation Commands by Job](#installation-commands-by-job)
5. [Tool Version Information](#tool-version-information)

---

## ✅ GitHub-Hosted Runner Pre-installed Tools

GitHub-hosted runners (`ubuntu-latest`) come with these tools pre-installed. **No installation required.**

### Core Development Tools
| Tool | Version | Purpose |
|------|---------|---------|
| **Git** | Latest | Source code checkout |
| **Docker** | 20.10+ | Container image building |
| **Docker Buildx** | Latest | Multi-platform builds |
| **Python 3** | 3.10+ | Python scripts & AWS CDK |
| **Node.js** | 18.x LTS | GitHub Actions scripts |
| **npm/yarn** | Latest | Package management |

### Azure Tools
| Tool | Version | Purpose |
|------|---------|---------|
| **Azure CLI** | Latest | Azure resource management |
| **Azure PowerShell** | Latest | PowerShell-based Azure automation |

### System Utilities
| Tool | Version | Purpose |
|------|---------|---------|
| **curl** | Latest | HTTP requests & health checks |
| **wget** | Latest | File downloads |
| **bash** | 5.x | Shell scripting |
| **grep** | Latest | Text search & filtering |
| **sed** | Latest | Text transformation |
| **tr** | Latest | Character translation |
| **awk** | Latest | Text processing |
| **paste** | Latest | Line merging |

### Build Tools
| Tool | Version | Purpose |
|------|---------|---------|
| **gcc/g++** | 11.x | C/C++ compilation |
| **make** | Latest | Build automation |
| **cmake** | Latest | Build system generator |

For complete list of pre-installed software, see: [GitHub Actions Runner Images](https://github.com/actions/runner-images/blob/main/images/linux/Ubuntu2204-Readme.md)

---

## 🔧 Self-Hosted Runner Requirements

If using self-hosted runners, you must manually install all required tools:

### Required Software
```bash
# Update package manager
sudo apt-get update

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Install Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Install Node.js (for GitHub Actions)
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install Python 3 (if not present)
sudo apt-get install -y python3 python3-pip

# Install jq (JSON processor)
sudo apt-get install -y jq

# Install bc (calculator)
sudo apt-get install -y bc

# Install Trivy (vulnerability scanner)
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
echo deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main | sudo tee -a /etc/apt/sources.list.d/trivy.list
sudo apt-get update
sudo apt-get install -y trivy

# Install Docker Buildx
mkdir -p ~/.docker/cli-plugins/
curl -SL https://github.com/docker/buildx/releases/latest/download/buildx-linux-amd64 -o ~/.docker/cli-plugins/docker-buildx
chmod +x ~/.docker/cli-plugins/docker-buildx
```

---

## 📦 Runtime Tool Installations

These tools are **NOT pre-installed** on GitHub-hosted runners and must be installed during workflow execution.

### Tools Requiring Installation

| Tool | Purpose | Installation Time | Size |
|------|---------|------------------|------|
| **jq** | JSON parsing & manipulation | ~5 seconds | 1.2 MB |
| **bc** | Mathematical calculations | ~3 seconds | 200 KB |
| **Trivy** | Container vulnerability scanning | ~20 seconds | 50 MB |

---

## 🚀 Installation Commands by Job

### Job 1: Build Docker Image

```bash
# Install required tools
sudo apt-get update
sudo apt-get install -y jq bc

# Verification
jq --version
bc --version
```

**Purpose:**
- `jq`: Parse Azure CLI JSON responses
- `bc`: Calculate time durations

**Estimated Installation Time:** ~10 seconds

---

### Job 2: Scan Docker Image

```bash
# Install required tools
sudo apt-get update
sudo apt-get install -y jq bc

# Install Trivy vulnerability scanner
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
echo deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main | sudo tee -a /etc/apt/sources.list.d/trivy.list
sudo apt-get update
sudo apt-get install -y trivy

# Verification
jq --version
bc --version
trivy --version
```

**Purpose:**
- `jq`: Parse Trivy JSON reports
- `bc`: Calculate vulnerability counts
- `trivy`: Scan container images for vulnerabilities

**Estimated Installation Time:** ~30 seconds

---

### Job 3: Push Docker Image

**No additional tools required.** Uses pre-installed:
- Docker
- Azure CLI

---

### Job 4: Setup Azure Infrastructure

```bash
# Install required tools
sudo apt-get update
sudo apt-get install -y jq

# Verification
jq --version
```

**Purpose:**
- `jq`: Parse Azure resource JSON responses

**Estimated Installation Time:** ~8 seconds

---

### Job 5: Deploy & Health Check

```bash
# Install required tools
sudo apt-get update
sudo apt-get install -y jq curl

# Verification
jq --version
curl --version
```

**Purpose:**
- `jq`: Parse revision lists and container app details
- `curl`: Perform HTTP health checks

**Estimated Installation Time:** ~8 seconds

---

## 📊 Tool Version Information

### Checking Installed Versions

```bash
# Azure CLI
az --version

# Docker
docker --version

# Docker Buildx
docker buildx version

# Python
python3 --version

# Node.js
node --version

# jq
jq --version

# bc
bc --version

# Trivy
trivy --version

# Git
git --version
```

### Expected Output (GitHub-Hosted Runner)

```
azure-cli                         2.54.0+
Docker version                    24.0.7
github.com/docker/buildx         v0.11.2
Python                            3.10.12
Node.js                           v18.18.0
jq                                1.6
bc                                1.07.1
Trivy Version                     0.46.0
git version                       2.42.0
```

---

## 🔍 Troubleshooting

### Issue: `jq: command not found`

**Solution:**
```bash
sudo apt-get update
sudo apt-get install -y jq
```

### Issue: `bc: command not found`

**Solution:**
```bash
sudo apt-get install -y bc
```

### Issue: `trivy: command not found`

**Solution:**
```bash
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
echo deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main | sudo tee -a /etc/apt/sources.list.d/trivy.list
sudo apt-get update
sudo apt-get install -y trivy
```

### Issue: Docker permission denied

**Solution:**
```bash
sudo usermod -aG docker $USER
newgrp docker
# Or logout and login again
```

### Issue: Azure CLI not authenticated

**Solution:**
```bash
# For OIDC (GitHub Actions)
az login --service-principal \
  --username $AZURE_CLIENT_ID \
  --tenant $AZURE_TENANT_ID \
  --federated-token $AZURE_FEDERATED_TOKEN

# For service principal
az login --service-principal \
  --username $AZURE_CLIENT_ID \
  --password $AZURE_CLIENT_SECRET \
  --tenant $AZURE_TENANT_ID
```

---

## 📝 Installation Scripts

### Complete Self-Hosted Runner Setup Script

Save as `setup-runner.sh`:

```bash
#!/bin/bash
set -e

echo "🔧 Setting up self-hosted GitHub Actions runner..."

# Update system
echo "📦 Updating system packages..."
sudo apt-get update
sudo apt-get upgrade -y

# Install Docker
echo "🐳 Installing Docker..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    rm get-docker.sh
    echo "✅ Docker installed"
else
    echo "✅ Docker already installed"
fi

# Install Azure CLI
echo "☁️ Installing Azure CLI..."
if ! command -v az &> /dev/null; then
    curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
    echo "✅ Azure CLI installed"
else
    echo "✅ Azure CLI already installed"
fi

# Install Node.js
echo "📦 Installing Node.js..."
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt-get install -y nodejs
    echo "✅ Node.js installed"
else
    echo "✅ Node.js already installed"
fi

# Install Python 3
echo "🐍 Installing Python 3..."
sudo apt-get install -y python3 python3-pip
echo "✅ Python 3 installed"

# Install jq
echo "📋 Installing jq..."
sudo apt-get install -y jq
echo "✅ jq installed"

# Install bc
echo "🔢 Installing bc..."
sudo apt-get install -y bc
echo "✅ bc installed"

# Install Trivy
echo "🔍 Installing Trivy..."
if ! command -v trivy &> /dev/null; then
    wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
    echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
    sudo apt-get update
    sudo apt-get install -y trivy
    echo "✅ Trivy installed"
else
    echo "✅ Trivy already installed"
fi

# Install Docker Buildx
echo "🏗️ Installing Docker Buildx..."
mkdir -p ~/.docker/cli-plugins/
curl -SL https://github.com/docker/buildx/releases/latest/download/buildx-linux-amd64 -o ~/.docker/cli-plugins/docker-buildx
chmod +x ~/.docker/cli-plugins/docker-buildx
echo "✅ Docker Buildx installed"

# Verify installations
echo ""
echo "🔍 Verifying installations..."
echo "Docker: $(docker --version)"
echo "Azure CLI: $(az --version | head -n1)"
echo "Node.js: $(node --version)"
echo "Python: $(python3 --version)"
echo "jq: $(jq --version)"
echo "bc: $(bc --version | head -n1)"
echo "Trivy: $(trivy --version | head -n1)"
echo "Docker Buildx: $(docker buildx version)"

echo ""
echo "✅ Self-hosted runner setup complete!"
echo ""
echo "⚠️ IMPORTANT: You need to logout and login again for Docker group changes to take effect."
echo "   Or run: newgrp docker"
```

**Usage:**
```bash
chmod +x setup-runner.sh
./setup-runner.sh
```

---

## 🎯 Quick Reference

### GitHub-Hosted Runner (ubuntu-latest)

**Pre-installed:** Docker, Azure CLI, Python, Node.js, Git, curl, wget, bash utilities  
**Requires Installation:** jq, bc, Trivy  
**Total Install Time:** ~40 seconds (all jobs combined)

### Self-Hosted Runner

**Pre-installed:** None (fresh Ubuntu installation)  
**Requires Installation:** Everything listed in "Self-Hosted Runner Requirements"  
**One-time Setup Time:** ~5-10 minutes

---

## 📚 Additional Resources

- [GitHub Actions Runner Images](https://github.com/actions/runner-images)
- [Azure CLI Documentation](https://docs.microsoft.com/en-us/cli/azure/)
- [Docker Documentation](https://docs.docker.com/)
- [Trivy Documentation](https://aquasecurity.github.io/trivy/)
- [jq Manual](https://stedolan.github.io/jq/manual/)

---

## 🔄 Updates & Maintenance

### Keeping Tools Updated

**GitHub-Hosted Runners:**
- Automatically updated by GitHub weekly
- No maintenance required

**Self-Hosted Runners:**
```bash
# Update all system packages
sudo apt-get update
sudo apt-get upgrade -y

# Update Azure CLI
az upgrade

# Update Trivy
sudo apt-get update
sudo apt-get install --only-upgrade trivy

# Update Docker
sudo apt-get update
sudo apt-get install --only-upgrade docker-ce docker-ce-cli
```

---

**Document Version:** 1.0  
**Last Updated:** November 24, 2025  
**Maintained by:** DevOps Team
