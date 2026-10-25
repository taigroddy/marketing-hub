# Implementation Plan: Architecture Cleanliness & Controller Purity (Feedback 3)

## 1. Overview & Context

This implementation addresses four architectural feedback items aligned during the `/grill-me` session:
1. **Consolidate Routes:** Remove duplicate outer `scope "v1/:platform"` in `config/routes.rb`. Keep all API endpoints strictly nested under `namespace :api do namespace :v1 do`.
2. **HTML Controller Purity:** HTML controllers (`CampaignsController`, `SessionsController`, `RegistrationsController`) must strictly render views (`index`, `show`, `new`, `edit`). Data submission/mutations must execute via client-side JavaScript (`fetch`) calling `/api/v1/*` JSON endpoints.
3. **Eliminate Controller Hacks:** Remove `html_browser_request?` and multi-format branching from API controllers (`Api::V1::PlatformCampaignsController` and `Api::V1::PlatformAccountsController`). API controllers strictly respond with JSON `{ success, data, errors }` (with the exception of 3rd-party OAuth redirect callbacks).
4. **Ruby Idiomatic Method Naming:** Rename generic step method names (`process`, `upsert_records`, etc.) across Dry::Transaction services to explicit, domain-specific, idiomatic Ruby names.

---

## 2. Tasks & Step-by-Step Breakdown

### Task 1: Idiomatic Ruby Method Naming in Services
Rename all generic step methods to domain-specific names:
- `Campaigns::CreateService`: rename `process` -> `create_campaign_record`
- `Campaigns::UpdateService`: rename `process` -> `update_campaign_budget`
- `PlatformCampaigns::PublishService`: rename `upsert_records` -> `persist_platform_campaigns`, and `enqueue_sync_jobs` -> `enqueue_sync_workers`
- `PlatformCampaigns::ResyncService`: rename `mark_pending` -> `mark_sync_status_pending`, and `enqueue_sync_job` -> `enqueue_resync_worker`
- `PlatformAccounts::ConnectService`: rename `process` -> `save_platform_account`
- `Auth::LoginService`: rename `process` -> `generate_session_tokens`
- `Auth::LogoutService`: rename `process` -> `revoke_user_token`
- `Auth::RefreshTokenService`: rename `process` -> `issue_new_tokens`
- `Auth::ConfirmEmailService`: rename `process` -> `confirm_user_account`
- Update all service specs to verify steps and behaviors remain 100% green.

### Task 2: Routes Consolidation
In `config/routes.rb`:
- Remove outer `scope "v1/:platform"` (lines 27-33).
- Ensure all API endpoints reside strictly under `namespace :api do namespace :v1 do`:
  - `resources :campaigns, only: [:index, :show, :create, :update]`
  - `resources :platform_accounts, only: [:index]`
  - `scope ":platform", constraints: { platform: /(facebook|google)/ }` containing:
    - `get "oauth/authorize"`
    - `get "oauth/callback"`
    - `post "oauth/callback"`
    - `post "campaigns/:id/publish"`
    - `post "campaigns/:id/resync"`
- Keep the external OAuth redirect entry point:
  `get "oauth/:platform/callback" => "api/v1/platform_accounts#callback", constraints: { platform: /(facebook|google)/ }`
- Refactor HTML resources:
  `resources :campaigns, only: [:index, :show, :new, :edit]` (delete `create` and `update`).

### Task 3: Controller Clean-up (Remove `html_browser_request?`)
- `Api::V1::PlatformCampaignsController`:
  - Completely remove `html_browser_request?`.
  - Ensure `publish` and `resync` return pure JSON with the standardized envelope `{ success, data, errors }`.
- `Api::V1::PlatformAccountsController`:
  - Remove `html_browser_request?`.
  - `authorize`: return pure JSON `{ success: true, data: { authorize_url: auth_url }, errors: nil }`.
  - `callback`: handles external browser redirect from OAuth provider; redirect to `dashboard_path` with flash notice/alert.
- Update `Api::V1::AuthController`:
  - In `login`: set `cookies[:jwt_token]` and `cookies[:refresh_token]` on successful login so browser requests seamlessly authenticate HTML pages, while returning standard JSON envelope.
  - In `logout`: clear cookies and return JSON.

### Task 4: UI Controller Purity & JS-driven Form Submissions
- `CampaignsController`:
  - Remove `create` and `update` actions. Controller only handles `index`, `show`, `new`, `edit`.
- `SessionsController` & `RegistrationsController`:
  - Purely render `new` view.
- Update Views & JavaScript:
  - `app/views/campaigns/new.html.erb`: Intercept form submit with JS `fetch()` POST to `/api/v1/campaigns`. On success redirect to `dashboard_path`, on error display inline error alert without page reload.
  - `app/views/campaigns/edit.html.erb`: Intercept form submit with JS `fetch()` PATCH to `/api/v1/campaigns/:id`. On success redirect to `dashboard_path`, on error display inline errors.
  - `app/views/campaigns/_platform_accounts_section.html.erb`: Publish form submit via JS `fetch()` POST to `/api/v1/:platform/campaigns/:id/publish`.
  - `app/views/campaigns/_platform_campaigns_section.html.erb`: Re-sync button click via JS `fetch()` POST to `/api/v1/:platform/campaigns/:id/resync`.
  - `app/views/sessions/new.html.erb`: Submit login credentials via JS `fetch()` to `/api/v1/auth/login`. On success redirect to `dashboard_path`.
  - `app/views/registrations/new.html.erb`: Submit registration via JS `fetch()` to `/api/v1/auth/register`. On success redirect to `login_path`.
  - Dashboard connect button: fetch `/api/v1/:platform/oauth/authorize` and redirect `window.location.href = data.authorize_url`.

### Task 5: Verification & Quality Gates
- Update Swagger/OpenAPI docs (`spec/requests/api/v1/` and `swagger/v1/swagger.yaml`) to match consolidated routes.
- Update Request & Controller specs to reflect pure JSON APIs and consolidated routes.
- Run tests:
  - `docker compose exec -T web bundle exec rspec` (Must be 0 failures, 0 mocks, branch coverage >= 80%).
  - `docker compose exec -T web bundle exec rubocop` (0 offenses).
  - `docker compose exec -T web bundle exec fasterer` (0 offenses).
