## Redis (Cache & Data Store)

### Overview
Redis is an in-memory data structure store used as a database, cache, and message broker.

### Location
```
redis/
├── docker-compose.yaml
└── .env
```

### Configuration Details
- **Password**: Stored in `.env`
- **Data Persistence**: `dump.rdb` file for data persistence

### Commands

#### Start Redis
```powershell
cd redis
docker compose up -d
```

#### Stop Redis
```powershell
docker compose down
```

### Verification Commands

#### Test Redis Connection (without password)
```powershell
docker exec -it <redis-container-name> redis-cli ping
```

**Expected Output**: `PONG`

#### Test Redis Connection (with password)
```powershell
docker exec -it <redis-container-name> redis-cli -a <password> ping
```

#### Check Redis Info
```powershell
docker exec -it <redis-container-name> redis-cli -a <password> info
```

#### Set and Get a Test Key
```powershell
docker exec -it <redis-container-name> redis-cli -a <password> set testkey "Hello World"
docker exec -it <redis-container-name> redis-cli -a <password> get testkey
```

**Expected Output**: `"Hello World"`
