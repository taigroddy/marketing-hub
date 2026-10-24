# Marketing Hub Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Xây dựng trọn vẹn ứng dụng Marketing Hub trên nền tảng Rails 8, PostgreSQL, Redis, Mailpit và Traefik chạy 100% trong Docker, cho phép quản lý và đồng bộ chiến dịch quảng cáo lên Facebook Ads (và preview Google Ads) theo kiến trúc phân tầng chuẩn mực, bảo mật tenant và cập nhật realtime với Turbo Stream.

**Architecture:** Kiến trúc phân tầng một chiều nghiêm ngặt: Controller (JWT Auth, Blueprinter, bypass params) $\rightarrow$ Service (`dry-transaction` + `dry-monads`) $\rightarrow$ Contract (`dry-validation`) $\rightarrow$ Model (không callback trigger job, DB transaction không gọi 3rd party, upsert thay vì loop). Tách riêng tầng Client Adapter (`Clients::OAuth::*`, `Clients::AdCampaign::*`) để giao tiếp với platform ngoài. Giao diện Rails View + Tailwind CSS + Stimulus nhận realtime Turbo Stream qua Redis.

**Tech Stack:** Ruby 3.3, Rails 8.0, PostgreSQL 16, Redis 7, Sidekiq, Mailpit, Traefik v3, Tailwind CSS, Turbo Stream, dry-transaction, dry-monads, dry-validation, blueprinter, jwt, rspec-rails, vcr, webmock, simplecov, rubocop, fasterer, rswag.

**Spec:** `docs/superpowers/specs/2026-10-24-marketing-hub-design.md` và `idea-marketing-hub.md`

---

## Global Constraints

- **Environment Isolation:** Toàn bộ công cụ và lệnh (rails, bundle, rspec, rubocop...) phải chạy trong Docker container thông qua Docker Compose; không cài đặt trên máy host.
- **Layer Integrity:** Controller chỉ gọi Service; Service chỉ gọi Contract, Model và Client; Model không trigger job qua callback. Không gọi ngang hàng hoặc vượt tầng.
- **Tenant Isolation:** Mọi truy vấn và tương tác tài nguyên (PlatformAccount, Campaign, PlatformCampaign) bắt buộc phải được scope theo `current_user`.
- **Database Transactions:** Không gọi API bên thứ ba (Client Adapter) bên trong DB transaction block. Dùng `upsert_all` cho các thao tác hàng loạt thay vì lặp từng record.
- **Routing Format:** Endpoints theo platform tuân theo: `v1/:platform/{{feature}}/{{action}}` với constraint `:platform => /(facebook|google)/`.
- **Token Security:** `access_token` và `refresh_token` trong `platform_accounts` bắt buộc được mã hóa qua `ActiveRecord::Encryption`.
- **Test Quality:** RSpec branch coverage $\ge 80\%$, sử dụng VCR recording thực tế thay vì fake WebMock data.
- **Documentation:** Mọi tài liệu phải nằm trong repository và viết đầy đủ.

---

## Review Focus

1. **User Tenant Leakage:** Thử nghiệm truy cập hoặc thao tác trên Campaign/PlatformAccount của User A bằng JWT của User B $\rightarrow$ Kết quả mong đợi: `404 Not Found` hoặc `403 Forbidden`, tuyệt đối không rò rỉ dữ liệu.
2. **Third-Party Failure in DB Transaction:** Mô phỏng lỗi kết nối Facebook Graph API trong quá trình sync $\rightarrow$ Kết quả mong đợi: DB transaction rollback an toàn, không có orphaned record, status được ghi nhận `failed` kèm `last_error_message`.
3. **Desync Detection on Campaign Budget Update:** Khi update budget của campaign hệ thống $\rightarrow$ `campaign.updated_at` lớn hơn `platform_campaign.synced_at`, hệ thống phải hiển thị trạng thái `Sai lệch` và kích hoạt nút `Re-sync`.
4. **Duplicate Publish Prevention:** Thử chọn lại platform account đã publish campaign để publish lần 2 $\rightarrow$ Kết quả mong đợi: Checkbox bị disable trên UI và Service trả về failure `:validation` nếu gọi trực tiếp qua API.
5. **Token Refresh Expiration:** Khi access_token hết hạn (`token_expires_at <= Time.current`) trong lúc sync $\rightarrow$ Hệ thống tự động kích hoạt refresh token flow qua client adapter để lấy token mới trước khi gọi Ads API.

---

### Task 1: Docker Compose & Traefik Reverse Proxy Infrastructure

**Files:**
- Create: `Dockerfile`
- Create: `docker-compose.yml`
- Create: `config/traefik/traefik.yml`
- Create: `.dockerignore`
- Create: `.env.example`

**Interfaces:**
- Consumes: Host Docker engine & `.env` configuration.
- Produces: Mạng Docker với 5 containers: `web` (Rails), `db` (Postgres 16), `redis` (Redis 7), `mailpit` (Mail server local), `traefik` (Reverse proxy).

- [ ] **Step 1: Write Dockerfile and docker-compose.yml**
  Thiết lập Dockerfile với Ruby 3.3, cài đặt nodejs/yarn/libpq/tzdata, cấu hình entrypoint script. `docker-compose.yml` khai báo 5 service: `web`, `db`, `redis`, `mailpit`, `traefik`. Cấu hình Traefik route `marketing.localhost` $\rightarrow$ `web:3000` và `mailchimp.localhost` $\rightarrow$ `mailpit:8025`.
- [ ] **Step 2: Run container build & start test**
  Chạy: `docker compose up -d db redis mailpit traefik`
  Kiểm tra: Các container khởi động `healthy` / running.
- [ ] **Step 3: Verify local domain routing**
  Chạy: `curl -I -H "Host: mailchimp.localhost" http://localhost`
  Kỳ vọng: HTTP 200 OK từ Mailpit Web UI.
- [ ] **Step 4: Commit**
  ```bash
  git add Dockerfile docker-compose.yml config/traefik/traefik.yml .dockerignore .env.example
  git commit -m "chore: setup docker compose, traefik, postgres, redis, and mailpit"
  ```

---

### Task 2: Rails 8 Bootstrap & Gem Ecosystem Configuration

**Files:**
- Create: Rails 8 core codebase via `docker compose run --rm web rails new . --database=postgresql --asset-pipeline=propshaft --css=tailwind`
- Modify: `Gemfile`
- Create: `spec/spec_helper.rb`, `spec/rails_helper.rb`, `spec/support/vcr.rb`, `spec/support/simplecov.rb`
- Create: `.rubocop.yml`, `.fasterer.yml`

**Interfaces:**
- Consumes: Docker environment từ Task 1.
- Produces: Ứng dụng Rails 8 đã bundle đầy đủ gems (`dry-transaction`, `dry-monads`, `dry-validation`, `blueprinter`, `jwt`, `sidekiq`, `redis`, `rspec-rails`, `vcr`, `webmock`, `simplecov`, `rubocop`, `fasterer`, `rswag`).

- [ ] **Step 1: Bootstrap Rails 8 within Docker container**
  Chạy: `docker compose run --rm web rails new . --force --database=postgresql --css=tailwind --skip-test`
- [ ] **Step 2: Add required gems to Gemfile**
  Thêm: `dry-transaction`, `dry-monads`, `dry-validation`, `blueprinter`, `jwt`, `sidekiq`, `redis`, `bcrypt`, `rspec-rails`, `vcr`, `webmock`, `simplecov`, `rubocop`, `rubocop-rails`, `fasterer`, `rswag`.
- [ ] **Step 3: Run bundle install & initialize RSpec & SimpleCov**
  Chạy: `docker compose run --rm web bundle install`
  Chạy: `docker compose run --rm web rails generate rspec:install`
  Cấu hình SimpleCov với `minimum_coverage 80` (branch coverage).
- [ ] **Step 4: Verify test suite execution**
  Chạy: `docker compose run --rm web bundle exec rspec`
  Kỳ vọng: 0 failures, SimpleCov coverage report xuất hiện.
- [ ] **Step 5: Commit**
  ```bash
  git add .
  git commit -m "chore: initialize rails 8 with postgres, tailwind, rspec, and core gems"
  ```

---

### Task 3: Base Architecture Classes (Service, Contract, Blueprint, Auth Concern)

**Files:**
- Create: `app/services/application_service.rb`
- Create: `app/contracts/application_contract.rb`
- Create: `app/blueprints/application_blueprint.rb`
- Create: `app/controllers/concerns/authenticable.rb`
- Create: `app/models/current.rb`
- Test: `spec/services/application_service_spec.rb`
- Test: `spec/controllers/concerns/authenticable_spec.rb`

**Interfaces:**
- Consumes: `dry-transaction`, `dry-monads`, `dry-validation`, `jwt`.
- Produces: Lớp nền tảng chuẩn mực cho Controller (`Authenticable`), Service (`ApplicationService` với block syntax `.call do |m| m.success; m.failure(:validation); m.failure end`), và Contract (`ApplicationContract`).

- [ ] **Step 1: Write failing test for ApplicationService step execution**
  Viết spec cho `ApplicationService` kiểm tra chạy flow `step :validation` (dry-validation Contract) và `step :process` trả về `Success(...)` hoặc `Failure(:validation, errors)`.
- [ ] **Step 2: Run test to verify failure**
  Chạy: `docker compose run --rm web bundle exec rspec spec/services/application_service_spec.rb`
  Kỳ vọng: FAIL (uninitialized constant ApplicationService).
- [ ] **Step 3: Implement ApplicationService & ApplicationContract**
  Tạo `app/services/application_service.rb` tích hợp `Dry::Transaction` và `Dry::Monads[:result, :do]`, định nghĩa cú pháp block `call`. Tạo `app/contracts/application_contract.rb` kế thừa `Dry::Validation::Contract`.
- [ ] **Step 4: Implement Authenticable concern & Current context**
  Tạo `app/models/current.rb` kế thừa `ActiveSupport::CurrentAttributes` với `attribute :user`. Tạo `app/controllers/concerns/authenticable.rb` giải mã Bearer JWT token từ header hoặc cookie, gán `Current.user`.
- [ ] **Step 5: Run tests to verify pass**
  Chạy: `docker compose run --rm web bundle exec rspec spec/services/application_service_spec.rb spec/controllers/concerns/authenticable_spec.rb`
  Kỳ vọng: PASS.
- [ ] **Step 6: Commit**
  ```bash
  git add app/services/ app/contracts/ app/blueprints/ app/controllers/concerns/ app/models/current.rb spec/
  git commit -m "feat: implement base architectural patterns for services, contracts, and authentication"
  ```

---

### Task 4: User Authentication & Mailpit Activation Flow

**Files:**
- Create: `db/migrate/YYYYMMDD_create_users.rb`
- Create: `app/models/user.rb`
- Create: `app/contracts/auth/register_contract.rb`
- Create: `app/contracts/auth/login_contract.rb`
- Create: `app/services/auth/register_service.rb`
- Create: `app/services/auth/confirm_email_service.rb`
- Create: `app/services/auth/login_service.rb`
- Create: `app/mailers/user_mailer.rb`
- Create: `app/views/user_mailer/confirmation_email.html.erb`
- Create: `app/blueprints/user_blueprint.rb`
- Create: `app/controllers/api/v1/auth_controller.rb`
- Create: `app/controllers/sessions_controller.rb`, `app/views/sessions/new.html.erb`, `app/views/registrations/new.html.erb`
- Test: `spec/models/user_spec.rb`
- Test: `spec/services/auth/register_service_spec.rb`
- Test: `spec/services/auth/confirm_email_service_spec.rb`
- Test: `spec/requests/api/v1/auth_spec.rb`

**Interfaces:**
- Consumes: `ApplicationService`, `ApplicationContract`, Mailpit SMTP.
- Produces: Luồng xác thực: Đăng ký $\rightarrow$ Gửi email kích hoạt $\rightarrow$ Bấm link email kích hoạt $\rightarrow$ Auto đăng nhập $\rightarrow$ Đăng nhập thủ công cấp JWT token.

- [ ] **Step 1: Generate User model migration & write failing model specs**
  Chạy: `docker compose run --rm web rails g migration CreateUsers email:string password_digest:string confirmation_token:string:index confirmed_at:datetime confirmation_sent_at:datetime`
  Viết spec cho `User` validation (email uniqueness, format, confirmation status).
- [ ] **Step 2: Run migration & verify test fails**
  Chạy: `docker compose run --rm web rails db:migrate`
  Chạy: `docker compose run --rm web bundle exec rspec spec/models/user_spec.rb`
  Kỳ vọng: FAIL.
- [ ] **Step 3: Implement User model, contracts, and services**
  Triển khai `app/models/user.rb` với `has_secure_password`. Triển khai `RegisterContract`, `LoginContract`. Triển khai `RegisterService` (tạo user, sinh token, trigger mail qua `UserMailer`), `ConfirmEmailService` (xác thực token, update `confirmed_at`, sinh JWT token), `LoginService` (kiểm tra password và confirmed_at, trả về JWT).
- [ ] **Step 4: Implement Auth Controllers & Tailwind Views**
  Tạo `Api::V1::AuthController` (API JSON với Blueprinter) và các màn hình View HTML (`/login`, `/register`, `/confirm_email/:token`) với Tailwind CSS. Khi click link kích hoạt, lưu JWT vào cookie và chuyển hướng vào Dashboard.
- [ ] **Step 5: Run tests to verify pass**
  Chạy: `docker compose run --rm web bundle exec rspec spec/services/auth/ spec/requests/api/v1/auth_spec.rb`
  Kỳ vọng: Tất cả tests PASS.
- [ ] **Step 6: Commit**
  ```bash
  git add app/ db/ spec/ config/routes.rb
  git commit -m "feat: implement user registration, email confirmation with mailpit, and jwt login"
  ```

---

### Task 5: 3rd Party Client Adapter Layer (OAuth & Ad Campaigns)

**Files:**
- Create: `app/clients/oauth/base_client.rb`
- Create: `app/clients/oauth/facebook_client.rb`
- Create: `app/clients/oauth/google_client.rb`
- Create: `app/clients/ad_campaign/base_client.rb`
- Create: `app/clients/ad_campaign/facebook_client.rb`
- Create: `app/clients/ad_campaign/google_client.rb`
- Test: `spec/clients/oauth/facebook_client_spec.rb`
- Test: `spec/clients/ad_campaign/facebook_client_spec.rb`
- Fixtures: `spec/fixtures/vcr_cassettes/facebook_oauth.yml`, `spec/fixtures/vcr_cassettes/facebook_create_campaign.yml`

**Interfaces:**
- Consumes: `.env` (`FB_APP_ID`, `FB_APP_SECRET`, `FB_AUTHORIZE_REDIRECT_UI`), Faraday/Net::HTTP.
- Produces: Chuẩn hoá interface tương tác với nền tảng quảng cáo (giống như Model/DataSource riêng biệt):
  - `OAuth::BaseClient#authorize_url`, `#exchange_code`, `#refresh_token`
  - `AdCampaign::BaseClient#create_campaign`, `#update_campaign`, `#fetch_campaign`

- [ ] **Step 1: Write failing specs for Facebook OAuth & Campaign Clients**
  Viết spec với VCR recording: test sinh link authorize, test exchange code lấy token, test gọi Graph API tạo campaign và update budget.
- [ ] **Step 2: Run tests to verify failure**
  Chạy: `docker compose run --rm web bundle exec rspec spec/clients/`
  Kỳ vọng: FAIL (uninitialized constant Clients).
- [ ] **Step 3: Implement Base Clients and Facebook Concrete Adapters**
  Triển khai `app/clients/oauth/base_client.rb` và `app/clients/oauth/facebook_client.rb`. Triển khai `app/clients/ad_campaign/base_client.rb` và `app/clients/ad_campaign/facebook_client.rb`. Triển khai skeleton cho Google (`GoogleClient < BaseClient`) raise `NotImplementedError`.
- [ ] **Step 4: Run tests to verify pass**
  Chạy: `docker compose run --rm web bundle exec rspec spec/clients/`
  Kỳ vọng: PASS với VCR cassette recording.
- [ ] **Step 5: Commit**
  ```bash
  git add app/clients/ spec/clients/ spec/fixtures/vcr_cassettes/
  git commit -m "feat: implement adapter pattern for oauth and ad campaign clients"
  ```

---

### Task 6: Platform Accounts STI & OAuth Connection Endpoints

**Files:**
- Create: `db/migrate/YYYYMMDD_create_platform_accounts.rb`
- Create: `app/models/platform_account.rb`
- Create: `app/models/platform_account/facebook.rb`
- Create: `app/models/platform_account/google.rb`
- Create: `app/contracts/platform_accounts/connect_contract.rb`
- Create: `app/services/platform_accounts/connect_service.rb`
- Create: `app/controllers/api/v1/platform_accounts_controller.rb`
- Create: `app/blueprints/platform_account_blueprint.rb`
- Create: `app/views/dashboard/index.html.erb` (Section 1: Danh sách Platform Accounts + Modal Liên kết mới)
- Test: `spec/models/platform_account_spec.rb`
- Test: `spec/services/platform_accounts/connect_service_spec.rb`
- Test: `spec/requests/api/v1/platform_accounts_spec.rb`

**Interfaces:**
- Consumes: `Clients::OAuth::FacebookClient`, `ActiveRecord::Encryption`, `Current.user`.
- Produces:
  - Model STI `PlatformAccount::Facebook`, `PlatformAccount::Google` với encrypted tokens.
  - Endpoint `v1/:platform/oauth/authorize` và `v1/:platform/oauth/callback` (giới hạn constraint `platform: /(facebook|google)/`).
  - Giao diện Section 1 trên Dashboard hiển thị danh sách accounts, nút popup "Liên kết mới" (Google disabled).

- [ ] **Step 1: Generate migration for PlatformAccount with STI and encryption columns**
  Tạo migration: `type:string:index`, `user_id:bigint:index`, `account_id:string`, `name:string`, `access_token:text`, `refresh_token:text`, `token_expires_at:datetime`, `refresh_token_expires_at:datetime`, `status:string`. Thêm unique index `[:user_id, :type, :account_id]`.
- [ ] **Step 2: Run migration and write failing model & service specs**
  Chạy: `docker compose run --rm web rails db:migrate`
  Viết spec cho `PlatformAccount` test mã hóa tự động `encrypts :access_token`, `encrypts :refresh_token`, và `ConnectService`.
- [ ] **Step 3: Implement Models, Service, and Routes**
  Khai báo `encrypts :access_token, :refresh_token` trong `PlatformAccount`. Khai báo routes `v1/:platform/oauth/authorize` và `v1/:platform/oauth/callback`. Triển khai `ConnectService` (nhận code từ callback, gọi `OAuthClient`, upsert tài khoản vào DB).
- [ ] **Step 4: Implement Dashboard Section 1 UI with Tailwind CSS**
  Xây dựng giao diện Section 1: Hiển thị các platform account đã kết nối. Trạng thái empty khi chưa có account. Popup "Liên kết mới" cho phép chọn Facebook (chuyển hướng sang OAuth URL) và Google (disabled kèm tooltip "Sắp ra mắt").
- [ ] **Step 5: Run tests to verify pass**
  Chạy: `docker compose run --rm web bundle exec rspec spec/models/platform_account_spec.rb spec/services/platform_accounts/ spec/requests/api/v1/platform_accounts_spec.rb`
  Kỳ vọng: PASS.
- [ ] **Step 6: Commit**
  ```bash
  git add app/ db/ spec/ config/routes.rb
  git commit -m "feat: implement platform accounts sti, token encryption, and oauth connection flow"
  ```

---

### Task 7: Campaigns Management & Strict Tenant Isolation

**Files:**
- Create: `db/migrate/YYYYMMDD_create_campaigns.rb`
- Create: `app/models/campaign.rb`
- Create: `app/contracts/campaigns/create_contract.rb`
- Create: `app/contracts/campaigns/update_budget_contract.rb`
- Create: `app/services/campaigns/create_service.rb`
- Create: `app/services/campaigns/update_budget_service.rb`
- Create: `app/blueprints/campaign_blueprint.rb`
- Create: `app/controllers/api/v1/campaigns_controller.rb`
- Create: `app/controllers/campaigns_controller.rb`
- Create: `app/views/campaigns/new.html.erb`, `app/views/campaigns/edit.html.erb`
- Test: `spec/models/campaign_spec.rb`
- Test: `spec/services/campaigns/create_service_spec.rb`
- Test: `spec/services/campaigns/update_budget_service_spec.rb`
- Test: `spec/requests/api/v1/campaigns_spec.rb`

**Interfaces:**
- Consumes: `Current.user`, `ApplicationService`, `ApplicationContract`.
- Produces: CRUD Campaign hệ thống (Create tối thiểu: name, objective, budget; Update: CHỈ cho phép sửa budget, các trường khác disabled). Toàn bộ query cô lập theo `Current.user`.

- [ ] **Step 1: Generate migration for Campaigns**
  Chạy: `docker compose run --rm web rails g migration CreateCampaigns user:references name:string objective:string budget:decimal status:string`
  Thêm validation constraints: `null: false` cho name, objective, budget.
- [ ] **Step 2: Run migration & write failing tests for tenant isolation & budget update**
  Chạy: `docker compose run --rm web rails db:migrate`
  Viết test: User A tạo campaign; User B cố gắng query hoặc update campaign của User A $\rightarrow$ trả về lỗi; Update request chứa params khác ngoài `budget` $\rightarrow$ các params khác bị bỏ qua hoặc từ chối.
- [ ] **Step 3: Implement Campaign model, Contracts, and Services**
  Triển khai `Campaign` model (`belongs_to :user`). Triển khai `CreateContract` (name, objective, budget) và `UpdateBudgetContract` (chỉ cho phép budget). Triển khai `CreateService` và `UpdateBudgetService`.
- [ ] **Step 4: Implement Dashboard Section 2 and Campaign Form Views**
  Giao diện Dashboard Section 2: Danh sách campaign, empty UI khi chưa có campaign nào kèm nút "Tạo campaign đầu tiên". Form tạo mới (`/campaigns/new`) và form cập nhật (`/campaigns/:id/edit` - disabled toàn bộ inputs chỉ cho sửa budget).
- [ ] **Step 5: Run tests to verify pass**
  Chạy: `docker compose run --rm web bundle exec rspec spec/models/campaign_spec.rb spec/services/campaigns/ spec/requests/api/v1/campaigns_spec.rb`
  Kỳ vọng: PASS.
- [ ] **Step 6: Commit**
  ```bash
  git add app/ db/ spec/ config/routes.rb
  git commit -m "feat: implement campaigns management with tenant isolation and budget-only editing"
  ```

---

### Task 8: Platform Campaigns Linking & Sidekiq Sync Engine

**Files:**
- Create: `db/migrate/YYYYMMDD_create_platform_campaigns.rb`
- Create: `app/models/platform_campaign.rb`
- Create: `app/jobs/sync_campaign_job.rb`
- Create: `app/services/platform_campaigns/publish_service.rb`
- Create: `app/services/platform_campaigns/resync_service.rb`
- Create: `app/controllers/api/v1/platform_campaigns_controller.rb`
- Create: `app/blueprints/platform_campaign_blueprint.rb`
- Create: `app/views/campaigns/show.html.erb` (Campaign Details: Section 1 Info, Section 2 Platform Accounts checkboxes + Sync button, Section 3 Linked Platform Campaigns list + Re-sync button)
- Test: `spec/models/platform_campaign_spec.rb`
- Test: `spec/services/platform_campaigns/publish_service_spec.rb`
- Test: `spec/services/platform_campaigns/resync_service_spec.rb`
- Test: `spec/jobs/sync_campaign_job_spec.rb`
- Test: `spec/requests/api/v1/platform_campaigns_spec.rb`

**Interfaces:**
- Consumes: `Clients::AdCampaign::FacebookClient`, `Sidekiq`, `PlatformAccount`, `Campaign`.
- Produces:
  - Bảng `platform_campaigns` liên kết trực tiếp `campaign_id` và `platform_account_id`.
  - Service `PublishService` (tạo liên kết pending, trigger Sidekiq job gọi Facebook client ngoài DB transaction, upsert record kết quả kèm `synced_at`).
  - Service `ResyncService` (phát hiện sai lệch giữa `campaign.updated_at` và `platform_campaign.synced_at`, đẩy job đồng bộ lại).
  - Routes: `POST /v1/:platform/campaigns/:id/publish` và `POST /v1/:platform/campaigns/:id/resync`.

- [ ] **Step 1: Generate migration for PlatformCampaigns**
  Tạo migration với `campaign_id:bigint:index`, `platform_account_id:bigint:index`, `external_campaign_id:string:index`, `synced_at:datetime`, `sync_status:string`, `last_error_message:text`. Unique index `[:campaign_id, :platform_account_id]`.
- [ ] **Step 2: Run migration & write failing tests for publish and resync flow**
  Chạy: `docker compose run --rm web rails db:migrate`
  Viết spec: Kiểm tra rule "Không gọi 3rd party trong DB transaction", rule "Sử dụng upsert_all", và test phát hiện sai lệch qua `synced_at`.
- [ ] **Step 3: Implement PlatformCampaign model, Services, and Sidekiq Job**
  Triển khai `PlatformCampaign` model. Triển khai `SyncCampaignJob` kế thừa `ApplicationJob`. Triển khai `PublishService` (validate checkbox platform account chưa từng publish campaign này; ghi nhận pending; gọi client adapter; upsert kết quả). Triển khai `ResyncService`.
- [ ] **Step 4: Implement Campaign Details View**
  Tạo `app/views/campaigns/show.html.erb` với:
  - **Section 1**: Tóm tắt thông tin campaign + nút Chỉnh sửa budget.
  - **Section 2**: Danh sách platform accounts của user kèm checkbox. Disable checkbox nếu account đó đã có trong `platform_campaigns`. Nút "Sync to platform".
  - **Section 3**: Danh sách `platform_campaigns` đã liên kết, hiển thị `synced_at`. Nếu `campaign.updated_at > platform_campaign.synced_at`, hiển thị nhãn "Sai lệch" và nút "Re-sync".
- [ ] **Step 5: Run tests to verify pass**
  Chạy: `docker compose run --rm web bundle exec rspec spec/models/platform_campaign_spec.rb spec/services/platform_campaigns/ spec/jobs/sync_campaign_job_spec.rb spec/requests/api/v1/platform_campaigns_spec.rb`
  Kỳ vọng: PASS.
- [ ] **Step 6: Commit**
  ```bash
  git add app/ db/ spec/ config/routes.rb
  git commit -m "feat: implement platform campaign synchronization engine and detail screen"
  ```

---

### Task 9: Realtime Synchronization with Turbo Streams & Redis

**Files:**
- Modify: `config/cable.yml`
- Create: `app/views/campaigns/_platform_accounts_section.html.erb`
- Create: `app/views/campaigns/_platform_campaigns_section.html.erb`
- Modify: `app/jobs/sync_campaign_job.rb`
- Modify: `app/views/campaigns/show.html.erb`
- Test: `spec/system/realtime_sync_spec.rb` hoặc `spec/channels/campaign_channel_spec.rb`

**Interfaces:**
- Consumes: Redis ActionCable adapter, Turbo Stream tags.
- Produces: Realtime DOM updates trên màn hình Campaign Details ngay khi `SyncCampaignJob` hoàn tất cập nhật `platform_campaign` mà không cần reload trang.

- [ ] **Step 1: Configure ActionCable for Redis**
  Cập nhật `config/cable.yml` trỏ tới `redis://redis:6379/1`.
- [ ] **Step 2: Write failing test for Turbo Stream broadcast**
  Viết spec kiểm tra `SyncCampaignJob` broadcast Turbo Stream tới stream `campaign_#{id}` khi hoàn tất sync.
- [ ] **Step 3: Implement partials and Turbo Stream broadcasts**
  Tách Section 2 và Section 3 thành partials có dom id rõ ràng: `#platform_accounts_list` và `#platform_campaigns_list`. Trong `SyncCampaignJob`, sau khi upsert/cập nhật status, gọi `Turbo::StreamsChannel.broadcast_replace_to("campaign_#{campaign.id}", target: "...", partial: "...")`. Trong `show.html.erb`, thêm `<%= turbo_stream_from "campaign_#{@campaign.id}" %>`.
- [ ] **Step 4: Run tests to verify pass**
  Chạy: `docker compose run --rm web bundle exec rspec spec/channels/ spec/jobs/sync_campaign_job_spec.rb`
  Kỳ vọng: PASS.
- [ ] **Step 5: Commit**
  ```bash
  git add config/cable.yml app/views/campaigns/ app/jobs/ spec/
  git commit -m "feat: implement realtime turbo-stream updates via redis for campaign details"
  ```

---

### Task 10: Rswag OpenAPI Documentation, Code Quality & Verification

**Files:**
- Create: `spec/requests/api/v1/auth_spec.rb` (rswag format)
- Create: `spec/requests/api/v1/campaigns_spec.rb` (rswag format)
- Create: `spec/requests/api/v1/platform_campaigns_spec.rb` (rswag format)
- Create: `config/initializers/rswag_api.rb`, `config/initializers/rswag_ui.rb`
- Create: `swagger/v1/swagger.yaml`
- Create: `README.md`
- Test: Run RuboCop, Fasterer, SimpleCov check.

**Interfaces:**
- Consumes: Toàn bộ API endpoints đã tạo.
- Produces: Tài liệu OpenAPI tương tác tại `/api-docs`, báo cáo RuboCop không có lỗi, báo cáo Fasterer sạch, SimpleCov branch coverage $\ge 80\%$.

- [ ] **Step 1: Write Rswag request specs for API endpoints**
  Viết rswag schema cho Auth endpoints, Platform Account endpoints, Campaign endpoints, Platform Campaign endpoints.
- [ ] **Step 2: Generate Swagger documentation**
  Chạy: `docker compose run --rm web rails rswag:specs:swaggerize`
  Kỳ vọng: `swagger/v1/swagger.yaml` được sinh đầy đủ.
- [ ] **Step 3: Run RuboCop and fix all lint offenses**
  Chạy: `docker compose run --rm web bundle exec rubocop -A`
  Kỳ vọng: 0 offenses.
- [ ] **Step 4: Run Fasterer performance inspection**
  Chạy: `docker compose run --rm web bundle exec fasterer`
  Kỳ vọng: 0 speed issues.
- [ ] **Step 5: Run full RSpec suite and verify branch coverage**
  Chạy: `docker compose run --rm web bundle exec rspec`
  Kỳ vọng: All tests pass, Branch coverage $\ge 80\%$.
- [ ] **Step 6: Write comprehensive README.md in repository**
  Viết `README.md` hướng dẫn chi tiết cách dựng Docker, cấu hình `.env`, chạy test, truy cập các domain `marketing.localhost`, `mailchimp.localhost`, và sử dụng Swagger UI.
- [ ] **Step 7: Commit**
  ```bash
  git add swagger/ README.md spec/ config/
  git commit -m "docs: generate rswag openapi documentation, complete readme, and verify quality gates"
  ```
