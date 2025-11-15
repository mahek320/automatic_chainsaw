## PostgreSQL (Relational Database)

### Overview
PostgreSQL is a powerful open-source relational database system.

### Location
```
postgres/
└── docker-compose.yaml
```

### Commands

#### Start PostgreSQL
```powershell
cd postgres
docker compose  up -d
```

#### Stop PostgreSQL
```powershell
docker compose down
```

### Verification Commands

#### Check PostgreSQL Status
```powershell
docker exec -it <postgres-container-name> pg_isready
```

**Expected Output**: `<hostname>:5432 - accepting connections`

#### Connect to PostgreSQL
```powershell
docker exec -it <postgres-container-name> psql -U <username>
```

#### List Databases
```powershell
docker exec -it <postgres-container-name> psql -U <username> -c "\l"
```

#### Create a Table
```powershell
docker exec -it <postgres-container-name> psql -U <username> -d <database-name> -c "CREATE TABLE test_table (id SERIAL PRIMARY KEY, name VARCHAR(100));"
```
**Expected Output**: `CREATE TABLE`

#### Insert Data into the Table
```powershell
docker exec -it <postgres-container-name> psql -U <username> -d <database-name> -c "INSERT INTO test_table (name) VALUES ('Test Entry');"
```
**Expected Output**: `INSERT 0 1`

#### Retrieve Data from the Table
```powershell
docker exec -it <postgres-container-name> psql -U <username> -d <database-name> -c "SELECT * FROM test_table;"
```
**Expected Output**:  `Test Entry
(1 row)`

#### Drop the Table
```powershell
docker exec -it <postgres-container-name> psql -U <username> -d <database-name> -c "DROP TABLE test_table;"
```
**Expected Output**: `DROP TABLE`

#### Important: Update Default Credentials:
Before running the Docker Compose setup, make sure to update the default PostgreSQL credentials in the docker-compose.yml file.
These credentials are used during container initialization and should be changed to prevent unauthorized access.

In your **docker-compose.yml file, update the following section:**

environment:
  - POSTGRES_PASSWORD=S3cret
  - POSTGRES_USER=postgres
  - POSTGRES_DB=postgres
Replace these with your own secure values:

**POSTGRES_PASSWORD:** `Set a strong, unique password.`

**POSTGRES_USER:** `Optionally change the default username.`

**POSTGRES_DB:** `You can rename the default database if desired.`

**Example:**

environment:
  - POSTGRES_PASSWORD=MyStrongPass123
  - POSTGRES_USER=myuser
  - POSTGRES_DB=mydatabase
