# Implementation Plan: Feedback Refactoring & Quality Alignment

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor Marketing Hub according to the 10 feedback items from `feedback.md`: streamline service/controller contracts, remove model validations, implement multi-device JWT refresh token architecture, encapsulate background jobs into standard services with separated trigger steps, fix HTTP error codes, remove redundant route constraints in services, and eliminate all test mocking in favor of real VCR cassettes.

**Architecture:** 
- Controller layer passes raw params via `full_request_params`.
- `ApplicationService` becomes a pure `Dry::Transaction` runner; services handle their own contracts and explicit steps (`process`, `enqueue_job`, etc.).
- ActiveRecord models remove `validates` in favor of Dry::Validation contracts and DB constraints.
- Multi-device sessions are stored in `user_tokens` table with hashed refresh tokens, short-lived JWT access tokens, and auto-refresh for web cookies.
- Background sync job delegates to `PlatformCampaigns::SyncService`.
- Tests run with zero stubs/mocks, using real VCR cassettes recorded with `FB_TEST_ACCESS_TOKEN`.

**Tech Stack:** Rails 8.0, Dry::Transaction, Dry::Validation, Dry::Monads, ActiveRecord, JWT, Redis, Sidekiq, Turbo Streams, VCR, WebMock, RSpec, facebookbusiness v26.0.

**Spec:** [feedback.md](file:///Users/trucanh/Downloads/marketing-hub/feedback.md)

## Global Constraints

- 100% Docker environment: all commands run inside `web` container or docker-compose.
- Zero mock/stub rule in tests (Item 10): NO `allow(...)`, `instance_double`, `double`, or `allow_any_instance_of`.
- Maintain test coverage $\ge 80\%$ branch coverage, 0 RSpec failures, 0 RuboCop offenses, 0 Fasterer offenses.
- Keep external 3rd-party API calls strictly outside DB transactions.

## Review Focus

1. User refresh token expiration and revocation: expired or revoked tokens must return 401 and clean up expired cookies.
2. Background sync failure in `PlatformCampaigns::SyncService`: failure during API call must correctly persist `failed` status and still broadcast via Turbo Streams.
3. Model persistence without model validations: invalid inputs rejected at contract level; database constraint violations properly caught if contracts are bypassed.
4. Update failures on existing campaigns: return 422 Unprocessable Content rather than 404 Not Found.
5. Multi-device concurrent logins: refreshing token on Device A must not invalidate session on Device B.

---

### Task 1: Streamline Controller, Service & Parameter Architecture (Items 1, 2, 7, 9)

**Files:**
- Modify: `app/services/application_service.rb`
- Modify: `app/services/auth/confirm_email_service.rb`
- Modify: `app/services/auth/login_service.rb`
- Modify: `app/services/auth/register_service.rb`
- Modify: `app/services/campaigns/create_service.rb`
- Modify: `app/services/campaigns/update_budget_service.rb`
- Modify: `app/services/platform_accounts/connect_service.rb`
- Modify: `app/services/platform_campaigns/publish_service.rb`
- Modify: `app/services/platform_campaigns/resync_service.rb`
- Modify: `app/controllers/application_controller.rb`
- Test: `spec/services/application_service_spec.rb`

**Interfaces:**
- Consumes: `ApplicationController#full_request_params` returning `Hash`
- Produces: `ApplicationService` without `validate_with` and `validation` helpers; services define their own validation step or omit it. Redundant platform checks removed from services whose routes already have constraints.

- [ ] **Step 1: Write test for ApplicationService as pure transaction runner**
- [ ] **Step 2: Remove `validate_with` and `validation` from `ApplicationService`**
- [ ] **Step 3: Remove duplicate `normalized = input.respond_to?(:to_unsafe_h)...` from all services**
- [ ] **Step 4: Remove redundant `platform` format checks in `PublishService`, `ResyncService`, and `ConnectService` (covered by route constraint)**
- [ ] **Step 5: Inline single-use private helper methods across services (Item 7)**
- [ ] **Step 6: Run RSpec for services to verify all pass**
- [ ] **Step 7: Commit changes**

---

### Task 2: Remove Validations from ActiveRecord Models (Item 3)

**Files:**
- Modify: `app/models/user.rb`
- Modify: `app/models/campaign.rb`
- Modify: `app/models/platform_account.rb`
- Modify: `app/models/platform_campaign.rb`
- Test: `spec/models/user_spec.rb`
- Test: `spec/models/campaign_spec.rb`
- Test: `spec/models/platform_account_spec.rb`
- Test: `spec/models/platform_campaign_spec.rb`

**Interfaces:**
- Consumes: Database schema constraints (`null: false`, unique indexes)
- Produces: Models with zero `validates` calls; `User` uses `has_secure_password(validations: false)`

- [ ] **Step 1: Update model specs to test associations, scopes, methods, and DB constraints without expecting ActiveRecord validation errors**
- [ ] **Step 2: Remove `validates :...` from `Campaign`, `PlatformCampaign`, `PlatformAccount`, and `User`**
- [ ] **Step 3: Update `User` model to use `has_secure_password validations: false`**
- [ ] **Step 4: Run model specs to verify all pass**
- [ ] **Step 5: Commit changes**

---

### Task 3: Multi-Device Authentication & Refresh Token Architecture (Item 5)

**Files:**
- Create: `db/migrate/YYYYMMDDHHMMSS_create_user_tokens.rb`
- Create: `app/models/user_token.rb`
- Create: `app/contracts/auth/refresh_token_contract.rb`
- Create: `app/services/auth/refresh_token_service.rb`
- Create: `app/services/auth/logout_service.rb`
- Modify: `app/models/user.rb`
- Modify: `app/services/auth/login_service.rb`
- Modify: `app/controllers/concerns/authenticable.rb`
- Modify: `app/controllers/sessions_controller.rb`
- Modify: `app/controllers/api/v1/auth_controller.rb`
- Modify: `config/routes.rb`
- Test: `spec/models/user_token_spec.rb`
- Test: `spec/services/auth/refresh_token_service_spec.rb`
- Test: `spec/services/auth/logout_service_spec.rb`
- Test: `spec/requests/api/v1/auth_spec.rb`

**Interfaces:**
- Consumes: `User` model, `BCrypt::Password` or `Digest::SHA256` for `token_digest`
- Produces:
  - `UserToken`: `belongs_to :user`, attributes: `user_id`, `token_digest`, `device_info`, `expires_at`, `revoked_at`
  - `Auth::LoginService` returns `user:`, `token:` (access_token), `refresh_token:`
  - `Auth::RefreshTokenService.call(refresh_token:, device_info:)` returns new access_token & updated session
  - `Auth::LogoutService.call(refresh_token:)` marks `revoked_at`
  - `Authenticable` auto-refreshes expired access_token in cookie for HTML requests

- [ ] **Step 1: Write migration for `user_tokens` table and run `db:migrate`**
- [ ] **Step 2: Create `UserToken` model and write unit specs**
- [ ] **Step 3: Implement `Auth::RefreshTokenService` and `Auth::LogoutService`**
- [ ] **Step 4: Update `Auth::LoginService` to create `UserToken` record and return refresh token**
- [ ] **Step 5: Update `Authenticable` to support cookie-based auto-refresh and token revocation**
- [ ] **Step 6: Expose `POST /api/v1/auth/refresh` and `POST /api/v1/auth/logout` endpoints**
- [ ] **Step 7: Update `SessionsController` and web login/logout views/cookies**
- [ ] **Step 8: Run auth request specs and verify all pass**
- [ ] **Step 9: Commit changes**

---

### Task 4: Standardize Background Job into Service & Explicit Steps (Items 4, 6)

**Files:**
- Create: `app/services/platform_campaigns/sync_service.rb`
- Modify: `app/jobs/sync_campaign_job.rb`
- Modify: `app/services/auth/register_service.rb`
- Modify: `app/services/platform_campaigns/publish_service.rb`
- Modify: `app/services/platform_campaigns/resync_service.rb`
- Test: `spec/services/platform_campaigns/sync_service_spec.rb`
- Test: `spec/jobs/sync_campaign_job_spec.rb`
- Test: `spec/services/auth/register_service_spec.rb`
- Test: `spec/services/platform_campaigns/publish_service_spec.rb`
- Test: `spec/services/platform_campaigns/resync_service_spec.rb`

**Interfaces:**
- Consumes: `Clients::AdCampaign::FacebookClient`, `Turbo::StreamsChannel`
- Produces:
  - `PlatformCampaigns::SyncService < ApplicationService`:
    - `step :check_resource`
    - `step :call_platform_api` (assert outside DB transaction)
    - `step :persist_result`
    - `step :broadcast_realtime`
  - `SyncCampaignJob#perform(id)` calls `PlatformCampaigns::SyncService.call(platform_campaign_id: id)`
  - Explicit transaction steps for enqueueing jobs and sending emails in `RegisterService`, `PublishService`, `ResyncService`

- [ ] **Step 1: Write unit spec for `PlatformCampaigns::SyncService`**
- [ ] **Step 2: Implement `PlatformCampaigns::SyncService` with explicit transactional steps**
- [ ] **Step 3: Refactor `SyncCampaignJob` to a one-line delegation to `PlatformCampaigns::SyncService`**
- [ ] **Step 4: Refactor `RegisterService` to separate `step :create_user` and `step :send_confirmation_email`**
- [ ] **Step 5: Refactor `PublishService` to separate `step :upsert_records` and `step :enqueue_sync_jobs`**
- [ ] **Step 6: Refactor `ResyncService` to separate `step :mark_pending` and `step :enqueue_sync_job`**
- [ ] **Step 7: Run specs for sync service, jobs, and transactional services to verify all pass**
- [ ] **Step 8: Commit changes**

---

### Task 5: Controller HTTP Status Code Compliance (Item 8)

**Files:**
- Modify: `app/controllers/api/v1/campaigns_controller.rb`
- Modify: `app/controllers/campaigns_controller.rb`
- Modify: `app/controllers/api/v1/platform_campaigns_controller.rb`
- Modify: `app/controllers/api/v1/platform_accounts_controller.rb`
- Test: `spec/requests/api/v1/campaigns_spec.rb`
- Test: `spec/requests/campaigns_spec.rb`
- Test: `spec/requests/api/v1/platform_campaigns_spec.rb`

**Interfaces:**
- Consumes: Service failure tags (`:not_found`, `:validation`, `:unauthorized`, `:failed_to_update`)
- Produces: Precise HTTP status codes:
  - Resource not found: `404 Not Found`
  - Input validation failure: `422 Unprocessable Content`
  - Update execution failure on existing record: `422 Unprocessable Content` (NOT 404)
  - Unauthorized: `401 Unauthorized`

- [ ] **Step 1: Write request tests expecting 422 when update fails and 404 when record is missing**
- [ ] **Step 2: Update `Api::V1::CampaignsController#update` and other controllers to handle distinct failures with correct status**
- [ ] **Step 3: Update HTML `CampaignsController#update` flash and error rendering**
- [ ] **Step 4: Run controller and request specs to verify all pass**
- [ ] **Step 5: Commit changes**

---

### Task 6: Purge Mocks and Re-record Real VCR Cassettes with Test Token (Item 10)

**Files:**
- Modify: `spec/clients/ad_campaign/facebook_client_spec.rb`
- Modify: `spec/clients/oauth/facebook_client_spec.rb`
- Modify: `spec/services/platform_accounts/connect_service_spec.rb`
- Modify: `spec/requests/api/v1/platform_accounts_spec.rb`
- Modify: `spec/services/campaigns/create_service_spec.rb`
- Modify: `spec/services/campaigns/update_budget_service_spec.rb`
- Modify: `spec/services/auth/register_service_spec.rb`
- Modify: `spec/jobs/sync_campaign_job_spec.rb`
- Create / Update: `spec/fixtures/vcr_cassettes/*.yml`
- Test: Full test suite

**Interfaces:**
- Consumes: `ENV['FB_TEST_ACCESS_TOKEN']`, real Facebook Marketing API / Graph API
- Produces: Pure, mock-free test suite with verified VCR cassettes and 0 stubbing

- [ ] **Step 1: Audit all specs and remove `allow(...)`, `instance_double(...)`, `allow_any_instance_of(...)`**
- [ ] **Step 2: Use `FB_TEST_ACCESS_TOKEN` to generate/update real VCR cassettes for Facebook client interactions**
- [ ] **Step 3: Update specs to assert on real records, real service results, and recorded VCR interactions**
- [ ] **Step 4: Run the full test suite (`bundle exec rspec`) and verify: 0 failures, 0 mocks, branch coverage >= 80%**
- [ ] **Step 5: Run `bundle exec rubocop` and `bundle exec fasterer` to verify 0 offenses**
- [ ] **Step 6: Commit changes**
