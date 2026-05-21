# Glomopay Assignment

A Rails 8 JSON API for user authentication, balance lookup, and deposits. Users log in with email and a 4-digit PIN, then use a bearer token to access protected endpoints.

## Versions

| Component   | Version   |
|-------------|-----------|
| Ruby        | 3.3.6     |
| Rails       | 8.0.5     |
| PostgreSQL  | 14+       |
| Puma        | 8.0.1     |
| bcrypt      | 3.1.22    |
| pg          | 1.6.3     |

Check locally:

```bash
ruby -v          # ruby 3.3.6
bin/rails -v     # Rails 8.0.5
postgres --version
bundle list | grep -E 'rails|bcrypt|puma|pg'
```

## Prerequisites

- Ruby 3.3.6 (see `.ruby-version`)
- PostgreSQL 14+ (Homebrew example: `brew services start postgresql@14`)
- Bundler

## Setup

```bash
cd glomopay-assignment
bundle install
bin/rails db:create db:migrate db:seed
bin/rails server
```

API base URL: **http://localhost:3000**

### Seed data

| Name  | Email               | PIN  | Initial balance |
|-------|---------------------|------|-----------------|
| Alice | alice@example.com   | 1234 | 1000.00         |
| Bob   | bob@example.com     | 5678 | 500.00          |

### PIN storage

PINs are **never stored in plain text**. `has_secure_password :pin` saves a bcrypt hash in `pin_digest`:

```
$2a$12$xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

Inspect in Rails console:

```bash
bin/rails console
```

```ruby
u = User.find_by(email: "alice@example.com")
u.pin_digest                    # bcrypt hash only
u.authenticate_pin("1234")    # => User if correct
u.authenticate_pin("9999")    # => false if wrong
```

Or via PostgreSQL:

```bash
psql glomopay_assignment_development -c "SELECT id, name, email, pin_digest, balance FROM users;"
```

## Authentication

Protected endpoints require:

```
Authorization: Bearer <token>
```

Each successful login generates a new token stored in `users.auth_token` and invalidates the previous one for that user.

---

## API endpoints

| Method | Path              | Auth required | Description        |
|--------|-------------------|---------------|--------------------|
| GET    | `/up`             | No            | Health check       |
| POST   | `/api/v1/login`   | No            | Login with email + PIN |
| GET    | `/api/v1/balance` | Yes           | Get current balance |
| POST   | `/api/v1/deposit` | Yes           | Deposit funds      |

### Health check

```
GET /up
```

**200 OK** — body: `OK`

---

### Login

```
POST /api/v1/login
Content-Type: application/json
```

**Request:**

```json
{
  "email": "alice@example.com",
  "pin": "1234"
}
```

**200 OK:**

```json
{
  "message": "Login successful",
  "user": {
    "id": 1,
    "name": "Alice",
    "email": "alice@example.com"
  },
  "token": "<auth_token>"
}
```

**401 Unauthorized:**

```json
{
  "error": "Invalid email or PIN"
}
```

---

### Get balance

```
GET /api/v1/balance
Authorization: Bearer <token>
```

**200 OK:**

```json
{
  "user": {
    "id": 1,
    "name": "Alice",
    "email": "alice@example.com"
  },
  "balance": 1000.0
}
```

**401 Unauthorized:**

```json
{
  "error": "Unauthorized"
}
```

---

### Deposit

```
POST /api/v1/deposit
Authorization: Bearer <token>
Content-Type: application/json
```

**Request:**

```json
{
  "amount": 250.50
}
```

**200 OK:**

```json
{
  "message": "Deposit successful",
  "deposited": 250.5,
  "new_balance": 1250.5
}
```

#### Amount rules

- Must be a **positive number**
- **At most 2 decimal places** (matches `decimal(15, 2)` in the database)
- Valid: `100`, `50.5`, `50.59`
- Invalid: `-5`, `0`, `"abc"`, `50.5903`

---

## Error handling

All errors return JSON with an `error` key (and sometimes a `hint`).

### Global handlers (`ApplicationController`)

| HTTP status | Exception / trigger | Response |
|-------------|---------------------|----------|
| **400** | `ArgumentError` | `{ "error": "<exception message>" }` |
| **400** | Invalid JSON body (`JSON::ParserError`, `ParseError`) | `{ "error": "Invalid JSON in request body", "hint": "..." }` |
| **401** | Missing/invalid bearer token | `{ "error": "Unauthorized" }` |
| **404** | `ActiveRecord::RecordNotFound` | `{ "error": "<message or Not found>" }` |
| **422** | `ActiveRecord::RecordInvalid` | `{ "error": "<validation messages>" }` |
| **500** | Any other `StandardError` | `{ "error": "An unexpected error occurred" }` |

### Login (`SessionsController`)

| Condition | Status | Error |
|-----------|--------|-------|
| Wrong email or PIN | 401 | `Invalid email or PIN` |

### Balance (`BalancesController`)

| Condition | Status | Error |
|-----------|--------|-------|
| No token or invalid token | 401 | `Unauthorized` |

### Deposit (`DepositsController`)

| Condition | Status | Error |
|-----------|--------|-------|
| No token or invalid token | 401 | `Unauthorized` |
| `amount` missing / null | 400 | `Amount is required` |
| `amount` empty string | 400 | `Amount is required` |
| `amount` not a number (e.g. `"abc"`, `true`, `[]`) | 400 | `Amount must be a positive number` |
| `amount` zero or negative | 400 | `Amount must be a positive number` |
| More than 2 decimal places (e.g. `50.5903`) | 400 | `Amount can have at most 2 decimal places` |
| Invalid JSON (e.g. `{"amount": abc}`) | 400 | `Invalid JSON in request body` + `hint` |

### Invalid JSON vs invalid amount

| Request body | What happens |
|--------------|--------------|
| `{"amount": abc}` | **Invalid JSON** — Rails cannot parse; returns `Invalid JSON in request body` |
| `{"amount": "abc"}` | **Valid JSON** — reaches validation; returns `Amount must be a positive number` |

Text values in JSON must use double quotes: `"abc"`, not `abc`.

### Model layer (`User`)

| Validation | When | Message |
|------------|------|---------|
| `name` presence | create/update | (422 via RecordInvalid) |
| `email` presence + uniqueness | create/update | (422 via RecordInvalid) |
| `pin` length = 4 | on create | (422 via RecordInvalid) |
| `balance` >= 0 | create/update | (422 via RecordInvalid) |
| `deposit!` positive amount | deposit | `ArgumentError` → 400 |

Deposits use `with_lock` for safe concurrent balance updates.

---

## Testing locally

### 1. Start the server

```bash
bin/rails server
```

Keep this terminal running. Use a **second terminal** for requests.

### 2. Health check

```bash
curl http://localhost:3000/up
```

### 3. Full flow (curl)

```bash
# Login — copy the token from the response
curl -X POST http://localhost:3000/api/v1/login \
  -H "Content-Type: application/json" \
  -d '{"email":"alice@example.com","pin":"1234"}'

# Balance
curl http://localhost:3000/api/v1/balance \
  -H "Authorization: Bearer YOUR_TOKEN"

# Deposit
curl -X POST http://localhost:3000/api/v1/deposit \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"amount": 100}'

# Balance again
curl http://localhost:3000/api/v1/balance \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### 4. Error handling tests (curl)

Replace `YOUR_TOKEN` with a valid token from login.

```bash
# Wrong PIN
curl -X POST http://localhost:3000/api/v1/login \
  -H "Content-Type: application/json" \
  -d '{"email":"alice@example.com","pin":"9999"}'
# => 401 Invalid email or PIN

# No auth token
curl http://localhost:3000/api/v1/balance
# => 401 Unauthorized

# Missing amount
curl -X POST http://localhost:3000/api/v1/deposit \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{}'
# => 400 Amount is required

# Non-numeric amount (valid JSON)
curl -X POST http://localhost:3000/api/v1/deposit \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"amount": "abc"}'
# => 400 Amount must be a positive number

# Too many decimal places
curl -X POST http://localhost:3000/api/v1/deposit \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"amount": 50.5903}'
# => 400 Amount can have at most 2 decimal places

# Negative amount
curl -X POST http://localhost:3000/api/v1/deposit \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"amount": -10}'
# => 400 Amount must be a positive number

# Invalid JSON (unquoted abc)
curl -X POST http://localhost:3000/api/v1/deposit \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"amount": abc}'
# => 400 Invalid JSON in request body
```

### 5. Postman

| Request | Method | URL | Headers | Body (raw JSON) |
|---------|--------|-----|---------|-----------------|
| Health | GET | `http://localhost:3000/up` | — | — |
| Login | POST | `http://localhost:3000/api/v1/login` | `Content-Type: application/json` | `{"email":"alice@example.com","pin":"1234"}` |
| Balance | GET | `http://localhost:3000/api/v1/balance` | `Authorization: Bearer <token>` | — |
| Deposit | POST | `http://localhost:3000/api/v1/deposit` | `Authorization: Bearer <token>`, `Content-Type: application/json` | `{"amount": 100}` |

In Postman, use **Authorization → Bearer Token** and paste only the token value.

### 6. Reset database (optional)

```bash
bin/rails db:reset   # drop, create, migrate, seed
```

---

## Project structure

```
app/
  controllers/
    application_controller.rb   # Auth, global error handling
    api/v1/
      sessions_controller.rb    # POST /api/v1/login
      balances_controller.rb    # GET  /api/v1/balance
      deposits_controller.rb    # POST /api/v1/deposit
  models/
    user.rb                     # PIN auth (bcrypt), deposits, tokens
config/
  routes.rb
db/
  migrate/20260521061429_create_users.rb
  seeds.rb
```

## Data model

**users**

| Column      | Type           | Notes |
|-------------|----------------|-------|
| name        | string         | Required |
| email       | string         | Required, unique index |
| pin_digest  | string         | bcrypt hash of 4-digit PIN |
| balance     | decimal(15,2)  | Default 0.00 |
| auth_token  | string         | Unique, regenerated on login |
| timestamps  | datetime       | |
