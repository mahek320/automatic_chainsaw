## Cerbos (Authorization Service)

### Overview
Cerbos is an open-source authorization service that provides fine-grained access control through policy-based rules. It allows you to define who can do what on which resources.

### Location
```
cerbos/
├── docker-compose.yaml
├── policies/
│   └── ticket.yaml
```

### Configuration Details
- **Image**: `ghcr.io/cerbos/cerbos:0.34.0`
- **Port**: `3592`
- **Policies**: Loaded from `./policies` directory (read-only)

### Custom Policies
The `ticket.yaml` policy defines access control for ticket resources:
- **Admin**: Full access (all actions)
- **Customer**: 
  - Can read/update their own tickets (where `cust_id` matches their ID)
  - Cannot create or delete tickets
  - Cannot access other customers' tickets

### Commands

#### Start Cerbos
```powershell
cd cerbos
docker-compose up -d
```

#### Stop Cerbos
```powershell
docker-compose down
```

#### View Logs
```powershell
docker logs my-cerbos-container
```

#### Check Status
```powershell
docker ps | grep cerbos
or
docker ps | findstr cerbos
```

### Verification Commands

#### 1. Check if policies are loaded
```powershell
curl http://localhost:3592/api/admin/policy
```

**Expected Output**: JSON list of loaded policies including the ticket policy

#### 2. Test Admin Access (Should ALLOW all actions)
```powershell
curl -X POST http://localhost:3592/api/check/resources `
  -H "Content-Type: application/json" `
  -d "{\"requestId\":\"test-admin\",\"includeMeta\":true,\"principal\":{\"id\":\"admin1\",\"roles\":[\"admin\"]},\"resources\":[{\"resource\":{\"kind\":\"ticket\",\"id\":\"ticket123\"},\"actions\":[\"read\",\"update\",\"delete\"]}]}"
```

**Expected Output**:
```json
{
  "requestId": "test-admin",
  "results": [{
    "resource": {"kind": "ticket", "id": "ticket123"},
    "actions": {
      "read": "EFFECT_ALLOW",
      "update": "EFFECT_ALLOW",
      "delete": "EFFECT_ALLOW"
    }
  }]
}
```

#### 3. Test Customer Access - Own Ticket (Should ALLOW read/update)
```powershell
curl -X POST http://localhost:3592/api/check/resources `
  -H "Content-Type: application/json" `
  -d "{\"requestId\":\"test-customer-own\",\"includeMeta\":true,\"principal\":{\"id\":\"customer1\",\"roles\":[\"customer\"]},\"resources\":[{\"resource\":{\"kind\":\"ticket\",\"id\":\"ticket123\",\"attr\":{\"cust_id\":\"customer1\"}},\"actions\":[\"read\",\"update\"]}]}"
```

**Expected Output**: `EFFECT_ALLOW` for both read and update

#### 4. Test Customer Access - Delete Action (Should DENY)
```powershell
curl -X POST http://localhost:3592/api/check/resources `
  -H "Content-Type: application/json" `
  -d "{\"requestId\":\"test-customer-delete\",\"includeMeta\":true,\"principal\":{\"id\":\"customer1\",\"roles\":[\"customer\"]},\"resources\":[{\"resource\":{\"kind\":\"ticket\",\"id\":\"ticket123\",\"attr\":{\"cust_id\":\"customer1\"}},\"actions\":[\"delete\"]}]}"
```

**Expected Output**: `EFFECT_DENY` for delete action

#### 5. Test Customer Access - Other's Ticket (Should DENY)
```powershell
curl -X POST http://localhost:3592/api/check/resources `
  -H "Content-Type: application/json" `
  -d "{\"requestId\":\"test-customer-other\",\"includeMeta\":true,\"principal\":{\"id\":\"customer1\",\"roles\":[\"customer\"]},\"resources\":[{\"resource\":{\"kind\":\"ticket\",\"id\":\"ticket456\",\"attr\":{\"cust_id\":\"customer2\"}},\"actions\":[\"read\"]}]}"
```

**Expected Output**: `EFFECT_DENY` for read action (cust_id mismatch)

