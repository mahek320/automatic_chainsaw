# Sample Streaming Flask App: Deployment & Testing Guide

This guide explains how to build, containerize, and deploy a simple streaming Flask app to Google Cloud Run and Azure Container Apps, including testing instructions.

## 1. App Overview

**app.py**
```python
from flask import Flask, Response, stream_with_context
import time
app = Flask(__name__)
@app.route('/stream')
def stream():
   def generate():
       for i in range(100):
           yield f"Chunk {i}\n"
           time.sleep(0.1)
        yield "DONE\n" # Add this line to snd "DONE" after all chunks
   return Response(stream_with_context(generate()), content_type='text/plain', headers={
       'Cache-Control': 'no-cache',
       'X-Accel-Buffering': 'no'  # Disable proxy buffering for streaming
   })
@app.route('/')
def health():
   return {"status": "ok"}, 200
if __name__ == '__main__':
   app.run(host='0.0.0.0', port=8080)
```

**requirements.txt**
```
Flask==3.0.0
gunicorn==21.2.0
```

**Dockerfile**
```
# Use official Python 3.11 slim image as base
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py .
EXPOSE 8080
CMD exec gunicorn --bind :8080 --workers 1 --threads 8 --worker-class gthread app:app
```


## 2. Build Docker Image

```sh
cd <project-directory>
docker build -t streaming-flask-app:latest .
```

**Sample Output:**
```
[+] Building 23.5s (10/10) FINISHED
 => [internal] load build definition from Dockerfile
 => [internal] load .dockerignore
 => [internal] load metadata for docker.io/library/python:3.11-slim
 => [1/5] FROM docker.io/library/python:3.11-slim
 => [internal] load build context
 => [2/5] WORKDIR /app
 => [3/5] COPY requirements.txt .
 => [4/5] RUN pip install --no-cache-dir -r requirements.txt
 => [5/5] COPY app.py .
 => exporting to image
 => => exporting layers
 => => writing image sha256:abc123def456...
 => => naming to docker.io/library/streaming-flask-app:latest
```


## 3. Tag & Push to Registries

### Google Cloud Artifact Registry (GCP AR)

1. **Tag the image:**
   ```sh
   docker tag streaming-flask-app:latest <GCP_REGION>-docker.pkg.dev/<GCP_PROJECT>/<REPOSITORY>/streaming-flask-app:latest
   ```
2. **Authenticate:**
   ```sh
   gcloud auth configure-docker <GCP_REGION>-docker.pkg.dev
   ```

**Sample Output:**
   
   ```sh
    Adding credentials for: us-central1-docker.pkg.dev
    Docker configuration file updated.
  ```

3. **Push:**

   ```sh
    docker push <GCP_REGION>-docker.pkg.dev/<GCP_PROJECT>/<REPOSITORY>/streaming-flask-app:latest
   ```
   **Sample Output:**
   ```
   The push refers to repository [us-central1-docker.pkg.dev/my-project/my-repo/streaming-flask-app]
   5f70bf18a086: Pushed
   d8d1e9f6e6b1: Pushed
   latest: digest: sha256:abc123def456... size: 1234
   ```

### Azure Container Registry (ACR)

1. **Tag the image:**
   ```sh
   docker tag streaming-flask-app:latest <ACR_NAME>.azurecr.io/streaming-flask-app:latest
   ```
2. **Login:**
   ```sh
   az acr login --name <ACR_NAME>
   ```
   **Sample Output:**
   ```
   Login Succeeded
   ```

3. **Push:**
   ```sh
   docker push <ACR_NAME>.azurecr.io/streaming-flask-app:latest
   ```
   **Sample Output:**
   ```
   The push refers to repository [myregistry.azurecr.io/streaming-flask-app]
   5f70bf18a086: Pushed
   d8d1e9f6e6b1: Pushed
   latest: digest: sha256:xyz789abc123... size: 1234
   ```



## 4. Deploy to Serverless Platforms

### Deploy to Google Cloud Run

```sh
gcloud run deploy streaming-flask-app \
  --image=<GCP_REGION>-docker.pkg.dev/<GCP_PROJECT>/<REPOSITORY>/streaming-flask-app:latest \
  --platform=managed \
  --region=<GCP_REGION> \
  --allow-unauthenticated \
  --port=8080
```

**Sample Output:**
```
Deploying container to Cloud Run service [streaming-flask-app] in project [my-project] region [us-central1]
✓ Deploying new service... Done.
  ✓ Creating Revision...
  ✓ Routing traffic...
Done.
Service [streaming-flask-app] revision [streaming-flask-app-00001-abc] has been deployed and is serving 100 percent of traffic.
Service URL: https://streaming-flask-app-abc123-uc.a.run.app
```

### Deploy to Azure Container Apps

```sh
az containerapp create \
  --name streaming-flask-app \
  --resource-group <RESOURCE_GROUP> \
  --environment <CONTAINERAPPS_ENVIRONMENT> \
  --image <ACR_NAME>.azurecr.io/streaming-flask-app:latest \
  --target-port 8080 \
  --ingress external
```

**Sample Output:**
```
Container app created. Access your app at https://streaming-flask-app.proudpond-abc12345.eastus.azurecontainerapps.io/
{
  "id": "/subscriptions/.../resourceGroups/my-rg/providers/Microsoft.App/containerApps/streaming-flask-app",
  "location": "East US",
  "name": "streaming-flask-app",
  "properties": {
    "configuration": {
      "ingress": {
        "external": true,
        "fqdn": "streaming-flask-app.proudpond-abc12345.eastus.azurecontainerapps.io",
        "targetPort": 8080
      }
    },
    "provisioningState": "Succeeded"
  }
}
```


## 5. Testing

### Health Check
```sh
curl <YOUR_SERVERLESS_URL>
```

**Sample Output:**
```json
{"status":"ok"}
```

### Streaming Endpoint
```sh
curl -N <YOUR_SERVERLESS_URL>/stream
```

**Sample Output:**
```
Chunk 0
Chunk 1
Chunk 2
Chunk 3
Chunk 4
...
Chunk 98
Chunk 99
DONE
```
*Note: Each chunk appears approximately every 0.1 seconds, demonstrating the streaming behavior.*

### Python Test Client
```python
import requests
import time
url = 'http://YOUR_SERVERLESS_URL/stream'
start_time = time.time()
with requests.get(url, stream=True) as response:
   for chunk in response.iter_content(chunk_size=None, decode_unicode=True):
       if chunk:
           elapsed = time.time() - start_time
           print(f"[{elapsed:.2f}s] {chunk}", end='', flush=True)
```

**Sample Output:**
```
[0.12s] Chunk 0
[0.23s] Chunk 1
[0.34s] Chunk 2
[0.45s] Chunk 3
[0.56s] Chunk 4
[0.67s] Chunk 5
...
[9.89s] Chunk 98
[10.01s] Chunk 99
[10.02s] DONE
```
*Note: The elapsed time shows real-time streaming with chunks arriving approximately every 0.1 seconds.*


## Replace Placeholders
- `<GCP_REGION>`, `<GCP_PROJECT>`, `<REPOSITORY>`: Your GCP details
- `<ACR_NAME>`: Your Azure Container Registry name
- `<RESOURCE_GROUP>`, `<CONTAINERAPPS_ENVIRONMENT>`: Your Azure resource group and environment
- `<URL>`: The deployed service URL


## References
- [Flask Streaming](https://flask.palletsprojects.com/)
- [Google Cloud Run Docs](https://cloud.google.com/run/docs)
- [Azure Container Apps Docs](https://learn.microsoft.com/en-us/azure/container-apps/)
