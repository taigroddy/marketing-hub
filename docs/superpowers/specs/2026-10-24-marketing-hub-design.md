# Marketing Hub - System Design Document

**Date:** 2026-10-24  
**Author:** AI Assistant & Engineering Team  
**Status:** Approved by User  
**Spec Reference:** `idea-marketing-hub.md`

---

## 1. Intent & The Why

Marketing Hub là ứng dụng web cho phép người dùng quản lý và triển khai các chiến dịch quảng cáo (Ads Campaign) tập trung, sau đó đồng bộ (publish/sync) sang các nền tảng quảng cáo phổ biến như Facebook Ads và Google Ads ở cấp độ demo cục bộ (local demo). 

Hệ thống giúp đơn giản hóa quy trình khởi tạo chiến dịch quảng cáo đa kênh, theo dõi trạng thái đồng bộ hai chiều theo thời gian thực (realtime), và quản lý an toàn các tài khoản quảng cáo của người dùng với tính năng cách ly dữ liệu độc lập (User-level isolation).

---

## 2. Goals, Non-Goals & Anti-Goals

### 2.1. Goals
- Cung cấp giao diện web thân thiện (Rails Views + Tailwind CSS + Stimulus + Turbo Stream) để:
  - Đăng ký, gửi email kích hoạt qua dịch vụ mail local (Mailpit tại `mailchimp.localhost`), tự động đăng nhập khi kích hoạt, đăng nhập lấy JWT token.
  - Kết nối tài khoản quảng cáo qua OAuth2 (hỗ trợ Facebook Ads, Google Ads tạm ẩn/disabled).
  - Quản lý chiến dịch: Tạo mới (name, objective, budget), xem chi tiết, cập nhật (chỉ cho phép sửa budget).
  - Đồng bộ chiến dịch sang các tài khoản quảng cáo nền tảng, hiển thị trạng thái và cho phép Re-sync khi có sai lệch ngân sách (`synced_at`).
  - Cập nhật trạng thái chiến dịch realtime tại màn hình Campaign Details bằng Turbo Stream qua Redis.
- Kiến trúc phân tầng rõ ràng, kiểm soát chặt chẽ luồng phụ thuộc:
  `Controller` -> `Service` (`dry-transaction` + `dry-monads`) -> `Contract` (`dry-validation`) -> `Model`.
- Tách biệt hoàn toàn tầng tương tác với bên thứ 3 thông qua Adapter Pattern (`Clients::OAuth::*` và `Clients::AdCampaign::*`).
- 100% môi trường cô lập trong Docker Compose (Traefik, Rails 8, PostgreSQL, Redis, Mailpit). Không cài đặt công cụ trực tiếp trên host machine.
- Đảm bảo chất lượng code: RSpec unit test (branch coverage >= 80%), VCR recording thực tế, RuboCop, Fasterer, Rswag OpenAPI docs.

### 2.2. Non-Goals
- Không xây dựng full production billing, thanh toán chi phí quảng cáo trực tiếp cho Meta/Google.
- Không hỗ trợ báo cáo phân tích số liệu chuyển đổi chuyên sâu (conversion tracking, attribution models) trong giai đoạn demo này.
- Chưa kích hoạt kết nối Google Ads (giữ UI disabled với gợi ý "Coming soon").

### 2.3. Anti-Goals
- Tuyệt đối không đặt business logic trong Controller hoặc Model callbacks.
- Tuyệt đối không gọi API bên thứ ba (3rd party) bên trong Database Transactions.
- Không dùng vòng lặp (`each { create / update }`) cho batch insert/update dữ liệu; bắt buộc dùng `upsert_all`.
- Không chia sẻ tài nguyên (Platform Accounts, Campaigns) giữa các User khác nhau.

---

## 3. Global Constraints & Conventions

1. **Docker Isolation**: Mọi tác vụ từ `rails new`, migration, bundle, chạy test, dev server đều chạy qua Docker Compose.
2. **Local Domains (Traefik v3)**:
   - `marketing.localhost` -> Rails Web app (port 3000)
   - `mailchimp.localhost` -> Mailpit Web UI (port 8025)
   - SMTP Port: `1025` (Mailpit nội bộ trong Docker network)
3. **Ruby & Rails Version**: Ruby 3.3.x, Rails 8.0.x API + Rails Views (Tailwind CSS, Propshaft/Importmap, Turbo Stream).
4. **Code Structure & Gem Stack**:
   - `dry-transaction`, `dry-monads`, `dry-validation`
   - `blueprinter` (JSON serialization cho Controller API)
   - `jwt` (Authentication & Current.user resolution)
   - `sidekiq` (Background jobs xử lý sync campaign)
   - `redis` (Cache, Sidekiq queue, ActionCable Turbo Stream backend)
   - `rspec-rails`, `vcr`, `webmock`, `simplecov`, `rubocop`, `fasterer`, `rswag`
5. **Layer Rules**:
   - `Controller`: Xác thực JWT token, lấy `current_user`, bypass request parameters trực tiếp sang Service, format output bằng Blueprinter. Không chứa logic nghiệp vụ.
   - `Service`: Kế thừa `ApplicationService`, sử dụng `step` của `dry-transaction`. Bước đầu tiên luôn là `step :validation` (dry-validation Contract) và `step :check_resource` (query DB). Các bước chính được định nghĩa trong `protected`, giảm tối đa hàm `private`.
   - `Model`: Không trigger Job qua callback. Mã hóa `access_token` và `refresh_token` bằng `ActiveRecord::Encryption` (AES-256-GCM).
   - `Client Layer`: Đóng vai trò như một Model/DataSource thứ hai để tương tác với 3rd party APIs, hoàn toàn độc lập với DB transaction.

---

## 4. Architectural Decisions & Approach

### 4.1. Routes & Endpoint Design
Các endpoint xử lý nghiệp vụ theo từng platform tuân theo quy ước:
`v1/:platform/{{feature}}/{{action if any}}` được giới hạn bởi constraints trong `routes.rb` (`constraints: { platform: /(facebook|google)/ }`).

Ví dụ:
- `GET /v1/:platform/oauth/authorize`: Trả về authorization URL chuyển hướng người dùng sang platform OAuth.
- `GET /v1/:platform/oauth/callback`: Nhận callback code, trao đổi access token và refresh token, lưu `PlatformAccount`.
- `POST /v1/:platform/campaigns/:id/publish`: Publish campaign hệ thống sang platform account tương ứng.
- `POST /v1/:platform/campaigns/:id/resync`: Đồng bộ lại thông tin campaign khi có sai lệch.

### 4.2. Client Layer (Adapter Pattern)
Tách biệt theo domain chức năng:
- **OAuth Clients**:
  - `app/clients/oauth/base_client.rb`
  - `app/clients/oauth/facebook_client.rb`
  - `app/clients/oauth/google_client.rb` (skeleton)
- **Ad Campaign Clients**:
  - `app/clients/ad_campaign/base_client.rb`
  - `app/clients/ad_campaign/facebook_client.rb`
  - `app/clients/ad_campaign/google_client.rb` (skeleton)

### 4.3. Database Schema

#### Bảng `users`
- `id`: bigint, PK
- `email`: string, null: false, unique index
- `password_digest`: string, null: false
- `confirmation_token`: string, indexed
- `confirmed_at`: datetime
- `confirmation_sent_at`: datetime
- `created_at`, `updated_at`: datetime

#### Bảng `platform_accounts` (Single Table Inheritance - STI)
- `id`: bigint, PK
- `user_id`: bigint, FK -> users (null: false, indexed)
- `type`: string, null: false, indexed (e.g., `PlatformAccount::Facebook`, `PlatformAccount::Google`)
- `account_id`: string, null: false (ID tài khoản ads phía Facebook/Google)
- `name`: string, null: false (Tên tài khoản quảng cáo)
- `access_token`: text (Mã hóa qua `ActiveRecord::Encryption`)
- `refresh_token`: text (Mã hóa qua `ActiveRecord::Encryption`)
- `token_expires_at`: datetime
- `refresh_token_expires_at`: datetime
- `status`: string, default: 'connected' (connected, disconnected, expired)
- `created_at`, `updated_at`: datetime
- Unique index: `[:user_id, :type, :account_id]`

#### Bảng `campaigns`
- `id`: bigint, PK
- `user_id`: bigint, FK -> users (null: false, indexed)
- `name`: string, null: false
- `objective`: string, null: false (e.g. `OUTCOME_TRAFFIC`, `OUTCOME_LEADS`, `OUTCOME_AWARENESS`)
- `budget`: decimal(12, 2), null: false
- `status`: string, default: 'draft' (draft, active, paused, completed)
- `created_at`, `updated_at`: datetime
- Index: `[:user_id, :created_at]`

#### Bảng `platform_campaigns`
- `id`: bigint, PK
- `campaign_id`: bigint, FK -> campaigns (null: false, indexed)
- `platform_account_id`: bigint, FK -> platform_accounts (null: false, indexed)
- `external_campaign_id`: string, indexed
- `synced_at`: datetime (Dùng so sánh với `campaign.updated_at` để hiển thị trạng thái Re-sync)
- `sync_status`: string, default: 'pending' (pending, synced, failed, desynced)
- `last_error_message`: text
- `created_at`, `updated_at`: datetime
- Unique index: `[:campaign_id, :platform_account_id]`

---

## 5. UI & User Flows

1. **Auth Flow**:
   - Đăng ký: Nhập email, mật khẩu. Gửi email xác nhận qua SMTP Mailpit (`mailchimp.localhost`).
   - Kích hoạt: Link trong email chứa `confirmation_token`. Bấm vào tự động kích hoạt tài khoản, sinh JWT token và đăng nhập vào Dashboard.
   - Đăng nhập / Quên mật khẩu: Quản lý qua Rails views và API.
2. **Dashboard (Màn hình chính)**:
   - **Section 1 - Platform Accounts**: Hiển thị thẻ các tài khoản đã liên kết. Nút `Liên kết mới` mở popup chọn Facebook hoặc Google (Google bị disable kèm hint "Coming soon").
   - **Section 2 - Campaigns List**: Danh sách chiến dịch của user. Nút `Tạo mới` chuyển đến form tạo campaign. Nút `View detail` điều hướng tới chi tiết.
3. **Campaign Create / Edit**:
   - Tạo mới: Nhập tên, mục tiêu (objective dropdown), ngân sách (budget).
   - Chỉnh sửa: Disable toàn bộ input ngoại trừ `budget`.
4. **Campaign Details**:
   - **Section 1**: Chi tiết chiến dịch (Tên, Mục tiêu, Ngân sách, Trạng thái) kèm nút Sửa.
   - **Section 2**: Danh sách Platform Accounts của user, trạng thái publish. Checkbox chọn tài khoản và nút `Sync to platform`. Checkbox bị disable nếu tài khoản đó đã được publish.
   - **Section 3**: Danh sách liên kết `PlatformCampaigns` (chiến dịch đã publish lên account nào, ID bên platform, thời điểm `synced_at`). Nếu `campaign.updated_at > platform_campaign.synced_at`, hiển thị nhãn `Sai lệch` kèm nút `Re-sync`.
   - **Realtime**: Sử dụng Turbo Stream đăng ký qua channel Redis. Khi Sidekiq job hoàn tất sync/re-sync, tự động cập nhật DOM ở Section 2 và Section 3 mà không cần reload trang.
