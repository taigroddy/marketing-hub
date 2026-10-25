# Project Guidelines & Coding Standards (Marketing Hub)

Tài liệu này là quy tắc bắt buộc áp dụng riêng cho project này. Mọi AI Agent, Subagent và Developer khi làm việc trên codebase đều phải tuân thủ nghiêm ngặt các nguyên tắc sau:

---

## 1. Kiến Trúc Phân Tầng (Architecture Layering)

Hệ thống tuân thủ nghiêm ngặt mô hình phân tầng:
`Controller -> Service -> Contract -> Job / Model / Client`

### A. Controller
- Chỉ đóng vai trò tiếp nhận request, chuyển đổi params bằng `full_request_params` (trên `ApplicationController`), và gọi Service thông qua cú pháp **Block Matcher**:
  ```ruby
  SomeService.call(full_request_params) do |m|
    m.success do |result|
      # Render hoặc redirect
    end

    m.failure(:validation) do |errors|
      # Xử lý lỗi validate (HTTP 422)
    end

    m.failure(:check_resource) do |errors|
      # Xử lý lỗi tài nguyên không tìm thấy (HTTP 404)
    end

    m.failure do |error|
      # Xử lý lỗi khác (HTTP 422 / 400)
    end
  end
  ```
- Không chứa business logic hay các thao tác trực tiếp với ActiveRecord (queries, save, update).
- **Format API (`/api/v1/*`):** Luôn trả về định dạng JSON (mặc định json, không cần phân nhánh mime-type phức tạp).
- **Chuẩn Response API:** Mọi response API dưới `/api/v1/*` bắt buộc tuân theo định dạng:
  ```json
  {
    "success": true,
    "data": { ... },
    "errors": null
  }
  ```
  Khi có lỗi:
  ```json
  {
    "success": false,
    "data": null,
    "errors": { "field": ["message"] } // hoặc string/array lỗi cụ thể
  }
  ```

### B. Service (`ApplicationService`)
- Kế thừa từ `ApplicationService`, sử dụng `Dry::Transaction` và `Dry::Monads`.
- `ApplicationService` là transaction runner thuần túy (không chứa method macro validate ngầm định).
- Mỗi service tự quản lý logic nghiệp vụ, tự quyết định và gọi Contract validate của riêng mình qua step riêng (nếu không cần validate thì không khai báo step validate).
- Các bước trigger background job (`SyncCampaignJob`) hoặc gửi email (`UserMailer.deliver_later`) phải được tách thành **một step riêng biệt** trong transaction.
- **Quy tắc gọi API bên thứ 3:** Tuyệt đối KHÔNG thực hiện gọi HTTP/API bên thứ 3 (Facebook, Google, v.v.) bên trong Database Transaction (`ActiveRecord::Base.transaction`).

### C. Contract (`ApplicationContract`)
- Kế thừa từ `ApplicationContract` (`Dry::Validation::Contract`).
- Chịu trách nhiệm toàn bộ việc kiểm tra kiểu dữ liệu, bắt buộc/tùy chọn, giới hạn độ dài, định dạng, và các rules nghiệp vụ đầu vào.

### D. Model (ActiveRecord)
- **Thin Model:** Không khai báo các lệnh `validates :...` ở model (đã được layer Contract đảm nhiệm).
- Giữ lại các DB constraints (NOT NULL, UNIQUE indexes, Foreign Keys) và các callbacks cốt lõi (như `has_secure_password(validations: false)`).
- **Multi-tenant Default Scope:**
  - `Campaign` và `PlatformAccount` cài đặt default scope theo `Current.user`:
    ```ruby
    default_scope { where(user_id: Current.user.id) if Current.user.present? }
    ```
  - Khi cần truy vấn toàn hệ thống (như trong background worker hoặc sync service), phải gọi tường minh `.unscoped`.

### E. Background Job
- Kế thừa `ApplicationJob`.
- Không chứa trực tiếp logic nghiệp vụ; background job đóng vai trò delegate gọi Service chuẩn tương ứng (ví dụ: `SyncCampaignJob` gọi `PlatformCampaigns::SyncService.call`).

---

## 2. Quy Tắc Clean Code: Không Tách Hàm Vụn Vặt (KISS & DRY)

- Không tách các private methods nhỏ nếu hàm đó chỉ được gọi đúng 1 lần tại 1 vị trí duy nhất.
- Giữ code tuyến tính, dễ đọc, dễ bảo trì, tránh phân mảnh logic thành quá nhiều hàm con 1-2 dòng không tái sử dụng.

---

## 3. Quy Tắc Kiểm Thử (Testing & VCR)

- **Zero-Mock Rule:** Tuyệt đối không dùng `allow(...)`, `instance_double`, `double`, hay `allow_any_instance_of` trong tests.
- Sử dụng Database thực tế (PostgreSQL container), records thực tế và VCR cassettes cho các tương tác với 3rd-party API.
- Nếu gặp trường hợp bất khả kháng không thể test mà không mock: **Bỏ dở và quay lại hỏi User để thống nhất giải pháp**, tuyệt đối không tự ý viết mock.
- **Tách nhỏ VCR Cassettes:**
  - Tách các file cassettes thành các unit nhỏ, nguyên tử (atomic) theo từng hành vi cụ thể (ví dụ: `facebook_create_campaign_success.yml`, `facebook_create_campaign_fail.yml`, `facebook_update_campaign_success.yml`, `facebook_update_campaign_fail.yml`, v.v.).
  - Tái sử dụng các cassette nguyên tử này ở nhiều test suite khác nhau (`client_spec`, `service_spec`, `job_spec`).
  - Đảm bảo cassettes không bị leak token (sử dụng VCR sensitive data filtering).
- Duy trì branch coverage >= 80%, RuboCop 0 offenses, Fasterer 0 offenses.
