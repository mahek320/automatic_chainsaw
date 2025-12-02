# How to Use UV Dockerfile Template 📖

This guide provides step-by-step instructions for using the UV-based Dockerfile templates.

## 📋 Table of Contents

1. [Prerequisites](#prerequisites)
2. [Basic Setup](#basic-setup)
3. [Building Without Private Packages](#building-without-private-packages)
4. [Building With Private ACR Packages](#building-with-private-acr-packages)
5. [Using Lockfiles](#using-lockfiles)
6. [Best Practices](#best-practices)
7. [Troubleshooting](#troubleshooting)

## ✅ Prerequisites

### Required:
- Docker Desktop installed
- Python service with `requirements.txt`
- Application entry point (e.g., `app.py`)

### Optional (for private packages):
- Azure CLI installed
- Access to Azure Container Registry (ACR)
- ACR authentication token

### Check Prerequisites:
```powershell
# Check Docker
docker --version

# Check Azure CLI (if using private packages)
az --version

# Check if you have requirements.txt
Test-Path requirements.txt
```

## 🚀 Basic Setup

### Step 1: Copy the Dockerfile

```powershell
# Navigate to your Python service directory
cd C:\path\to\your\python-service

# Copy the UV Dockerfile
Copy-Item "Dockerfile-Template\uv\Dockerfile" .\Dockerfile

# Optional: Also copy .dockerignore from parent template
Copy-Item "Dockerfile-Template\.dockerignore" .\.dockerignore
```

### Step 2: Verify Your Project Structure

Your project should look like this:

```
your-service/
├── app.py              # Your application entry point
├── requirements.txt    # Python dependencies
├── Dockerfile          # UV Dockerfile (just copied)
└── .dockerignore       # Exclusion patterns
```

### Step 3: Review requirements.txt

```txt
# requirements.txt
flask==2.3.0
requests==2.31.0
python-dotenv==1.0.0

# Add your dependencies here
```

## 🔨 Building Without Private Packages

If you only use public packages from PyPI:

### Build Command:

```powershell
# Basic build
docker build -t my-service:latest .

# With build output
docker build -t my-service:latest . --progress=plain

# Time the build to see UV speed
Measure-Command {
    docker build -t my-service:latest .
}
```

### Expected Output:

```
[+] Building 12.3s (15/15) FINISHED
 => [internal] load build definition from Dockerfile
 => [internal] load .dockerignore
 => [builder 1/6] FROM python:3.11-slim
 => [builder 2/6] COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv
 => [builder 3/6] RUN apt-get update && apt-get install...
 => [builder 4/6] WORKDIR /app
 => [builder 5/6] COPY requirements.txt .
 => [builder 6/6] RUN uv pip install --system --no-cache -r requirements.txt
 => [stage-1 2/5] RUN adduser --disabled-password...
 => [stage-1 3/5] WORKDIR /app
 => [stage-1 4/5] COPY --from=builder /usr/local/lib/python3.11/site-packages...
 => [stage-1 5/5] RUN chown -R appuser:appuser /app
 => exporting to image
```

### Run Your Container:

```powershell
# Run in foreground
docker run -p 5000:5000 my-service:latest

# Run in background
docker run -d -p 5000:5000 --name my-service my-service:latest

# View logs
docker logs my-service

# Test your service
Invoke-WebRequest http://localhost:5000

# Stop and remove
docker stop my-service
docker rm my-service
```

## 🔐 Building With Private ACR Packages

If you have private packages in Azure Container Registry:

### Step 1: Get ACR Token

```powershell
# Set your ACR name
$ACR_NAME = "yourregistryname"

# Option 1: Create a dedicated token (recommended)
az acr token create `
  --name pip-build-token `
  --registry $ACR_NAME `
  --scope-map _repositories_pull `
  --expiration-in-days 30

# Get the token password
$ACR_TOKEN = az acr token credential generate `
  --name pip-build-token `
  --registry $ACR_NAME `
  --password1 `
  --query "passwords[0].value" `
  --output tsv

# Option 2: Use admin credentials (not recommended for production)
$ADMIN_CREDS = az acr credential show --name $ACR_NAME
$ACR_TOKEN = ($ADMIN_CREDS | ConvertFrom-Json).passwords[0].value
```

### Step 2: Update requirements.txt

```txt
# requirements.txt

# ============================================
# PUBLIC PACKAGES (from PyPI)
# ============================================
flask==2.3.0
requests==2.31.0
sqlalchemy==2.0.23

# ============================================
# PRIVATE PACKAGES (from ACR)
# ============================================
your-private-package==1.0.0
company-auth-lib==2.1.0
internal-utils==3.0.0
```

### Step 3: Build with Authentication

```powershell
# Set variables
$ACR_NAME = "yourregistryname"
$ACR_TOKEN = "your-token-here"  # From Step 1

# Build with private package support
docker build `
  --build-arg PIP_INDEX_URL="https://${ACR_NAME}.azurecr.io/pypi/simple/" `
  --build-arg PIP_EXTRA_INDEX_URL="https://pypi.org/simple" `
  --build-arg PIP_TOKEN="${ACR_TOKEN}" `
  --build-arg PIP_TRUSTED_HOST="${ACR_NAME}.azurecr.io" `
  -t my-service:latest .
```

### Step 4: Verify Private Packages Installed

```powershell
# Check installed packages
docker run --rm my-service:latest pip list

# Check specific private package
docker run --rm my-service:latest pip show your-private-package

# Verify it runs
docker run -d -p 5000:5000 --name test-service my-service:latest
docker logs test-service
```

### Step 5: Save Credentials Securely

```powershell
# Save to environment variables (session only)
$env:ACR_NAME = "yourregistryname"
$env:ACR_TOKEN = "your-token-here"

# Or save to a secure file (add to .gitignore!)
@{
    ACR_NAME = $ACR_NAME
    ACR_TOKEN = $ACR_TOKEN
} | ConvertTo-Json | Out-File -FilePath .\.env.build.json

# Add to .gitignore
Add-Content .gitignore "`n.env.build.json"
```

## 🔒 Using Lockfiles (Maximum Speed)

For the fastest builds and guaranteed reproducibility:

### Step 1: Install UV Locally

```powershell
# Install UV on your machine
pip install uv

# Verify installation
uv --version
```

### Step 2: Generate Lockfile

```powershell
# Generate lockfile from requirements.txt
uv pip compile requirements.txt -o uv.lock

# If you have private packages, configure authentication first
$env:UV_INDEX_URL = "https://token:${ACR_TOKEN}@${ACR_NAME}.azurecr.io/pypi/simple/"
$env:UV_EXTRA_INDEX_URL = "https://pypi.org/simple"

# Then generate lockfile
uv pip compile requirements.txt -o uv.lock
```

### Step 3: Review Lockfile

```powershell
# View lockfile contents
Get-Content uv.lock | Select-Object -First 20

# Example output:
# # This file is autogenerated by uv
# flask==2.3.0 \
#     --hash=sha256:abc123... \
#     --hash=sha256:def456...
# requests==2.31.0 \
#     --hash=sha256:ghi789...
```

### Step 4: Use Lockfile Dockerfile

```powershell
# Copy lockfile Dockerfile
Copy-Item "Dockerfile-Template\uv\Dockerfile.lockfile" .\Dockerfile

# Make sure uv.lock is in the same directory
Test-Path uv.lock  # Should return True

# Build with lockfile (ultra-fast!)
docker build `
  --build-arg PIP_INDEX_URL="https://${ACR_NAME}.azurecr.io/pypi/simple/" `
  --build-arg PIP_EXTRA_INDEX_URL="https://pypi.org/simple" `
  --build-arg PIP_TOKEN="${ACR_TOKEN}" `
  -t my-service:latest .
```

### Step 5: Commit Lockfile to Git

```powershell
# Add lockfile to version control
git add uv.lock

# Commit
git commit -m "Add UV lockfile for reproducible builds"

# Push
git push
```

### Step 6: Update Lockfile When Dependencies Change

```powershell
# When you update requirements.txt, regenerate lockfile
uv pip compile requirements.txt -o uv.lock

# Review changes
git diff uv.lock

# Commit updated lockfile
git add uv.lock requirements.txt
git commit -m "Update dependencies"
```


## 📝 Best Practices

### 1. Use Lockfiles in Production

```powershell
# Development: Use regular Dockerfile
docker build -f Dockerfile -t app:dev .

# Production: Use lockfile Dockerfile
docker build -f Dockerfile.lockfile -t app:prod .
```

### 2. Keep Lockfiles Updated

```powershell
# Update lockfile when dependencies change
uv pip compile requirements.txt -o uv.lock
git add uv.lock requirements.txt
git commit -m "Update dependencies and lockfile"
```

### 3. Use Build Scripts

Create a `build.ps1`:

```powershell
param(
    [Parameter(Mandatory=$true)]
    [string]$ImageName,
    
    [Parameter(Mandatory=$false)]
    [string]$Tag = "latest",
    
    [Parameter(Mandatory=$false)]
    [switch]$UseLockfile
)

$dockerfile = if ($UseLockfile) { "Dockerfile.lockfile" } else { "Dockerfile" }
$fullName = "${ImageName}:${Tag}"

Write-Host "Building $fullName with $dockerfile..."

$startTime = Get-Date

if ($env:ACR_NAME -and $env:ACR_TOKEN) {
    docker build `
        -f $dockerfile `
        --build-arg PIP_INDEX_URL="https://$env:ACR_NAME.azurecr.io/pypi/simple/" `
        --build-arg PIP_EXTRA_INDEX_URL="https://pypi.org/simple" `
        --build-arg PIP_TOKEN="$env:ACR_TOKEN" `
        --build-arg PIP_TRUSTED_HOST="$env:ACR_NAME.azurecr.io" `
        -t $fullName `
        .
} else {
    docker build -f $dockerfile -t $fullName .
}

$duration = ((Get-Date) - $startTime).TotalSeconds
Write-Host "✅ Built in ${duration}s"
```

Usage:
```powershell
.\build.ps1 -ImageName my-service
.\build.ps1 -ImageName my-service -UseLockfile
.\build.ps1 -ImageName my-service -Tag v1.0.0 -UseLockfile
```

### 4. Monitor Build Times

```powershell
# Compare build times
$pipTime = Measure-Command { docker build -f Dockerfile.pip -t app:pip . }
$uvTime = Measure-Command { docker build -f Dockerfile -t app:uv . }

Write-Host "pip build: $($pipTime.TotalSeconds)s"
Write-Host "uv build: $($uvTime.TotalSeconds)s"
Write-Host "Speedup: $([math]::Round($pipTime.TotalSeconds / $uvTime.TotalSeconds, 1))x"
```

### 5. Cache Docker Layers

```powershell
# Use BuildKit for better caching
$env:DOCKER_BUILDKIT = 1

# Build with cache
docker build --build-arg BUILDKIT_INLINE_CACHE=1 -t app:latest .

# Use cache from registry
docker build --cache-from myregistry.azurecr.io/app:latest -t app:latest .
```

## 🐛 Troubleshooting

### Issue: Build is slow on first run

**Expected behavior:** First build downloads Python base image and packages

**Solution:** Subsequent builds will be much faster due to caching
```powershell
# First build: ~15-20s
docker build -t app:latest .

# Second build (no code changes): ~2-3s
docker build -t app:latest .
```

### Issue: "uv: not found" error

**Cause:** UV binary not copied correctly

**Solution:** Verify Dockerfile has:
```dockerfile
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv
```

### Issue: Private package not found

**Cause:** Authentication failure or package doesn't exist

**Solution:**
```powershell
# Verify token is valid
az acr repository list --name $ACR_NAME --output table

# Test authentication
$headers = @{
    Authorization = "Basic $([Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("token:${ACR_TOKEN}")))"
}
Invoke-WebRequest -Uri "https://${ACR_NAME}.azurecr.io/v2/_catalog" -Headers $headers
```

### Issue: Build fails with "package conflict"

**Cause:** UV's better dependency resolution found a conflict pip missed

**Solution:** This is good! Fix the actual conflict:
```powershell
# See which packages conflict
uv pip install -r requirements.txt --dry-run

# Update requirements.txt to resolve conflict
```

### Issue: Different package versions than with pip

**Cause:** UV resolves dependencies more accurately

**Solution:** 
```powershell
# Compare versions
docker run --rm app:pip pip list > pip-list.txt
docker run --rm app:uv pip list > uv-list.txt
Compare-Object (Get-Content pip-list.txt) (Get-Content uv-list.txt)

# If everything works, UV's versions are probably better!
```

### Issue: Want to force exact same versions as pip

**Solution:** Use lockfile approach:
```powershell
# Generate lockfile with current environment
pip freeze > requirements.lock
uv pip compile requirements.lock -o uv.lock
```

## ✅ Verification Checklist

After building, verify:

- [ ] Image builds successfully
- [ ] Application starts without errors
- [ ] All imports work correctly
- [ ] Private packages are installed
- [ ] API endpoints respond correctly
- [ ] Build time is improved (vs pip)
- [ ] Image size is reasonable (~280MB for typical Flask app)

```powershell
# Complete verification script
$IMAGE = "my-service:latest"

# Build
docker build -t $IMAGE .

# Run
docker run -d -p 5000:5000 --name test $IMAGE

# Wait for startup
Start-Sleep -Seconds 3

# Test health endpoint
Invoke-WebRequest http://localhost:5000/health

# Check logs
docker logs test

# Check installed packages
docker exec test pip list

# Cleanup
docker stop test
docker rm test

Write-Host "✅ All checks passed!"
```

## 📚 Next Steps

1. ✅ You've built with UV Dockerfile
2. 📊 Check [COMPARISON.md](COMPARISON.md) for performance details
3. 🔄 Integrate into CI/CD pipeline
4. 📦 Consider using lockfiles for production
5. 🚀 Roll out to more services

---

**Need More Help?**
- 📖 See [README.md](README.md) for overview
- 📊 See [COMPARISON.md](COMPARISON.md) for pip vs UV comparison


**Template Version:** 2.1  
**Last Updated:** November 24, 2025
