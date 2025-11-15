## Debezium PostgreSQL CDC Setup Guide
This guide explains how to set up and verify a Debezium Change Data Capture (CDC) pipeline using Docker, Kafka, and PostgreSQL, with commands and outputs to help verify functionality.
### Overview of Debezium
Debezium is an open-source distributed platform for capturing real-time changes in your databases and streaming those changes to Apache Kafka. It supports various databases, including PostgreSQL, and works by reading the database transaction logs (WAL in PostgreSQL) to capture insert, update, and delete operations.

By deploying Debezium along with Kafka in the same network (as is assumed here), Debezium connects by default to the Kafka broker on its internal Docker network without requiring extra configurations. This simplifies integration and ensures low-latency data streaming.

### Location
Project file structure:
```
debezium/
└── docker-compose.yaml
└── register-pg.json
```

### Commands

#### Start Debezium
```powershell
cd debezium
docker compose  up -d
```

#### Stop Debezium
```powershell
docker compose down
```

### Connector Registration
Prepare your register-pg.json file with the PostgreSQL connector configuration and register Debezium's connector:

```powershell
curl -X POST http://localhost:8083/connectors \
  -H "Content-Type: application/json" \
  --data @register-pg.json
```

### Ingest data to PostgreSQL for Data Replication
#### Insert test records into PostgreSQL: [ postgres db ]

`INSERT INTO public.customers (id, full_name, email) VALUES (1, 'Soundararajan C', 'soundararajanmdu@gmail.com');`

`INSERT INTO public.customers (id, full_name, email) VALUES (2, 'J S', 'js@gmail.com');`

#### Verify with:

`SELECT * FROM public.customers;`

#### Expected:
```
 id |   full_name   |       email       
----+---------------+-------------------
  1 | Soundararajan C  | soundararajanmdu@gmail.com
  2 | J S   | js@gmail.com
(2 rows)
```
### Kafka-Related Verification Commands
#### Checking Connector Status
##### Verify that the Debezium connector is running:

```powershell
curl http://localhost:8083/connectors/pg-connector/status | jq
```

**Expected simplified output excerpt:**

```json
{
  "name": "pg-connector",
  "connector": {
    "state": "RUNNING"
  },
  "tasks": [
    {
      "id": 0,
      "state": "RUNNING"
    }
  ]
} 
```
### Listing Kafka Topics
#### List all Kafka topics present in the broker, including Debezium-generated topics with prefix dbz.:

```powershell
docker exec -it broker /opt/kafka/bin/kafka-topics.sh \
  --list --bootstrap-server localhost:9092
  ```
#### Example output showing default Kafka topics and Debezium CDC topics:

```
__consumer_offsets
connect-configs
connect-offsets
connect-status
dbz.public.customers
test-topic
```
Here, topics prefixed with **dbz**. are created by Debezium for CDC streams.

### Consuming CDC Events from Kafka Topic
#### Consume CDC change events from the beginning of the dbz.public.customers topic:

```powershell
docker exec -it broker /opt/kafka/bin/kafka-console-consumer.sh \
  --topic dbz.public.customers \
  --bootstrap-server localhost:9092 \
  --from-beginning
  ```
#### Sample output snippet for two captured insert events:

```json
{
  "payload": {
    "before": null,
    "after": {
      "id": 1,
      "full_name": "Soundararajan C",
      "email": "soundararajanmdu@gmail.com"
    },
    "op": "r"
  }
}
{
  "payload": {
    "before": null,
    "after": {
      "id": 2,
      "full_name": "J S",
      "email": "js@gmail.com"
    },
    "op": "r"
  }
}
```
### To delete connector
```powershell
curl -X DELETE http://localhost:8083/connectors/pg-connector
```
This sends an HTTP DELETE request to the Kafka Connect REST API endpoint for the connector named pg-connector, removing the connector and stopping its data capture process.

Note that deleting the connector will not automatically remove the PostgreSQL replication slot created by Debezium. If you want to recreate the connector with the same name later, you may need to manually clean up the replication slot in PostgreSQL to avoid conflicts.

This command is standard for Kafka Connect connectors and is used to unregister and stop Debezium or any other connector instances.

### **Important Notes**
The Debezium connector uses PostgreSQL logical decoding with the pgoutput plugin, a replication slot, and a publication for streaming changes.

The Kafka broker assumed here is running in the same Docker network as Debezium, allowing it to use the default internal Kafka bootstrap server (localhost:9092 inside the container network).

**Adjust host and port values based on your environment if Kafka and Debezium are running separately.**

