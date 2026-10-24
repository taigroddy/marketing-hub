# Marketing Hub 🚀

An omnichannel digital marketing campaign management platform built with **Ruby on Rails 8.0**, **Hotwire (Turbo 8 & Stimulus)**, and a production-grade **REST API**. The platform enables centralized campaign orchestration, budget management, and multi-channel synchronization across major ad platforms (Facebook Ads, Google Ads).

---

## 🏗️ Architecture & Tech Stack

The application follows a clean layered architecture with strict separation of concerns, multi-tenant isolation, and resilient background processing:

- **Presentation Layer**: Rails Controllers handling dual formats (REST API JSON responses & Turbo 8 HTML views). Session authentication for web browser workflows; stateless JWT Bearer token authentication for API requests.
- **Service Layer (`app/services/`)**: Business transactions powered by `dry-transaction` and `dry-monads`. Every service defines sequential `step` methods returning `Success(result)` or `Failure(error)`.
- **Validation Contracts (`app/contracts/`)**: Input validation separated from database models using `dry-validation`.
- **API Adapters (`app/clients/`)**: External HTTP API clients (`Clients::OAuth::*`, `Clients::AdCampaign::*`) managing OAuth handshakes and platform ad synchronization. All 3rd-party HTTP communication occurs strictly outside database transactions.
- **Serialization Layer (`app/blueprints/`)**: High-performance JSON serialization via `blueprinter` (`UserBlueprint`, `CampaignBlueprint`, `PlatformCampaignBlueprint`, `PlatformAccountBlueprint`).
- **Asynchronous Processing**: Background synchronization managed by `Sidekiq` (`SyncCampaignJob`) backed by Redis.
- **Real-Time Communication**: Live UI updates powered by ActionCable and Turbo Stream broadcasts over Redis Pub/Sub.
- **Security & Encryption**: Sensitive tokens (such as OAuth access tokens and client secrets) are encrypted at rest using Rails `ActiveRecord::Encryption`.

---

## 🐳 Services & Ports

All dependencies run containerized via Docker Compose, isolated on the `marketing-net` bridge network:

| Service | Container Name | Technology | Internal Port | Host / Exposed Port | Routing Domain / Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Traefik** | `marketing_traefik` | Traefik v3 | `80` | `0.0.0.0:80` | Edge reverse proxy routing HTTP traffic |
| **Web** | `marketing_web` | Rails 8 / Puma 8 | `3000` | Internally routed | `http://marketing.localhost` |
| **Mailpit** | `marketing_mailpit` | Mailpit (Mock SMTP/Web) | `1025`, `8025` | Internally routed | `http://mailchimp.localhost` (Web UI), SMTP `1025` |
| **Database** | `marketing_db` | PostgreSQL 16 Alpine | `5432` | `5432` | Application & Test PostgreSQL storage |
| **Redis** | `marketing_redis` | Redis 7 Alpine | `6379` | `6379` | Sidekiq queue, ActionCable Pub/Sub, cache |

> **Note on Local Domains**: Add the following entries to your `/etc/hosts` file (or ensure `*.localhost` resolves to `127.0.0.1`):
> ```text
> 127.0.0.1 marketing.localhost mailchimp.localhost
> ```

---

## 🚀 Getting Started / Local Setup

### Prerequisites
- Docker Engine $\ge 24.0$
- Docker Compose v2

### Setup Steps

1. **Clone the repository**:
   ```bash
   git clone <repository_url>
   cd marketing-hub
   ```

2. **Configure Environment Variables**:
   Copy the provided `.env.example` file to `.env`:
   ```bash
   cp .env.example .env
   ```
   Verify or customize keys (PostgreSQL credentials, Redis URL, Facebook app credentials, and Active Record encryption keys).

3. **Build and Start Container Services**:
   ```bash
   docker compose up -d
   ```

4. **Initialize Database**:
   Create, migrate, and seed the database schema:
   ```bash
   docker compose run --rm web rails db:setup
   ```

5. **Access the Application**:
   - Web Application: [`http://marketing.localhost`](http://marketing.localhost)
   - Mailpit Web Interface: [`http://mailchimp.localhost`](http://mailchimp.localhost)
   - OpenAPI Swagger UI: [`http://marketing.localhost/api-docs`](http://marketing.localhost/api-docs)

---

## 📖 OpenAPI / Swagger Documentation

API documentation is generated using **Rswag** adhering to the OpenAPI 3.0.1 specification.

- **Interactive Swagger UI**: [`http://marketing.localhost/api-docs`](http://marketing.localhost/api-docs)
- **OpenAPI Schema (YAML)**: [`http://marketing.localhost/api-docs/v1/swagger.yaml`](http://marketing.localhost/api-docs/v1/swagger.yaml)

### Documented Endpoints

- **Authentication (`/api/v1/auth/`)**:
  - `POST /api/v1/auth/register`: User registration with email confirmation dispatch.
  - `POST /api/v1/auth/login`: User login returning JWT Bearer token.
  - `GET /api/v1/auth/confirm/{token}`: Account email activation.
  - `GET /api/v1/auth/me`: Profile retrieval for authenticated user.
- **Platform Accounts (`/v1/{platform}/oauth/`)**:
  - `GET /v1/{platform}/oauth/authorize`: Initiates OAuth authorization flow.
  - `GET /v1/{platform}/oauth/callback`: Code exchange and ad account binding.
  - `GET /api/v1/platform_accounts`: List connected platform ad accounts.
- **Campaigns (`/api/v1/campaigns/`)**:
  - `GET /api/v1/campaigns`: Multi-tenant scoped list of marketing campaigns.
  - `POST /api/v1/campaigns`: Create draft campaign.
  - `GET /api/v1/campaigns/{id}`: Detailed campaign representation.
  - `PATCH /api/v1/campaigns/{id}`: Update campaign budget.
- **Platform Campaigns (`/v1/{platform}/campaigns/`)**:
  - `POST /v1/{platform}/campaigns/{id}/publish`: Publish campaign to platform accounts.
  - `POST /v1/{platform}/campaigns/{id}/resync`: Synchronize updated details and budget.

### Regenerating Swagger Documentation
When endpoints or schemas are updated, regenerate the OpenAPI YAML file:
```bash
docker compose run --rm web rails rswag:specs:swaggerize
```

---

## 🧪 Quality Gates & Verification

The project adheres to strict automated code quality standards:

### 1. Full RSpec Test Suite & Code Coverage
Runs all unit, request, client, and integration tests with **SimpleCov** branch coverage analysis (enforcing $\ge 80\%$ branch coverage):
```bash
docker compose run --rm web bundle exec rspec
```

### 2. RuboCop Static Analysis
Ensures adherence to Rails omakase coding conventions with zero offenses:
```bash
docker compose run --rm web bundle exec rubocop
```
To run safe autocorrection:
```bash
docker compose run --rm web bundle exec rubocop -A
```

### 3. Fasterer Performance Audit
Detects slow Ruby idioms and performance anti-patterns:
```bash
docker compose run --rm web bundle exec fasterer
```

---

## 📐 Code Conventions & Design Rules

To maintain codebase readability, testability, and reliability, adhere to the following principles:

1. **Controller Result Matching**:
   Use block matcher syntax for handling Dry-Transaction results:
   ```ruby
   Campaigns::CreateService.call(full_request_params) do |m|
     m.success do |result|
       render json: { campaign: CampaignBlueprint.render_as_hash(result[:campaign]) }, status: :created
     end

     m.failure(:validation) do |errors|
       render json: { errors: errors }, status: :unprocessable_entity
     end

     m.failure do |error|
       render json: { error: error }, status: :unprocessable_entity
     end
   end
   ```

2. **Standardized Parameters (`full_request_params`)**:
   Always pass `full_request_params` from controllers into service objects. It merges query params, path parameters, request body, and scopes `current_user` securely.

3. **Service Object Steps**:
   Keep service step methods atomic and focused. Each step must return `Success(...)` or `Failure(...)`.
   ```ruby
   class CreateService < ApplicationService
     step :validate
     step :persist
     ...
   end
   ```

4. **Model Callback Restrictions**:
   Active Record models should represent data schemas and associations. Avoid lifecycle callbacks (`after_save`, `after_commit`) for external API interactions or complex business logic. Side effects belong in service objects or background jobs.

5. **External API Calls Outside Database Transactions**:
   Never invoke external HTTP requests (Facebook Ads API, Google Ads API) inside `ActiveRecord::Base.transaction`. Doing so holds database connections open across network latencies, risking pool exhaustion.
