## MongoDB (NoSQL Database)

### Overview
MongoDB is a document-oriented NoSQL database. This setup includes initialization scripts and persistent data storage.

### Location
```
mongodb/
├── docker-compose.yaml
├── db/
│   └── mongo-init.js
```

### Configuration Details
- **Initialization Script**: `mongo-init.js` runs on first startup
- **Data Persistence**: `mongodb-data/` directory stores database files

### Commands

#### Start MongoDB
```powershell
cd mongodb
docker-compose  up -d
```

#### Stop MongoDB
```powershell
docker-compose  down
```

#### Stop and Remove Data (⚠️ Destructive)
```powershell
docker-compose  down -v
```

### Verification Commands

#### Check MongoDB Status
```powershell
docker exec -it testMongoDB mongosh -u admin -p password --authenticationDatabase admin
or
docker exec -it <mongodb-container-name> mongosh --eval "db.adminCommand('ping')"
```

**Expected Output**: `{ ok: 1 }`

#### List Databases
```powershell
docker exec -it <mongodb-container-name> mongosh --eval "show dbs"
```

#### Connect to MongoDB Shell
```powershell
docker exec -it <mongodb-container-name> mongosh
```

### **Important note** :
Please update the credentials in the .env file with the secured credentials for the MongoDB setup. Overwrite the sample credentials provided in the .env file to ensure proper and secure database connectivity.
