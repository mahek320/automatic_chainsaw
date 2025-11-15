## OpenMetadata (Metadata Management)

### Overview
OpenMetadata is an open-source metadata platform for data discovery, observability, and governance.

### Location
```
openmeta/
├── docker-compose.yml
```

### Configuration Details
- **Database Backend**: PostgreSQL (data stored in `docker-volume/db-data/`)
- **Alternative**: MySQL configuration available

### Commands

#### Start OpenMetadata
```powershell
cd openmeta
docker-compose up -d
```

#### Stop OpenMetadata
```powershell
docker-compose down
```

### Verification Commands

#### Check OpenMetadata UI
Open browser: `http://localhost:8585`

**Expected Output**: OpenMetadata login page

#### Check All Containers
```powershell
docker-compose ps
```

#### Default login credentials: [ should get changed once initial login is done ]
**Username :**  `admin@open-metadata.org`
**Password :**  `admin`
