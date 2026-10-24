1. Ở ApplicationController, tạo ra 1 function full_request_params để giảm code `normalized = input.respond_to?(:to_unsafe_h) ? input.to_unsafe_h : input` trong service.
2. Bỏ các function `validate_with` và `validation` trong `ApplicationService` để làm đúng tiêu chuẩn, mỗi service sẽ quản lí đúng bussiness logic mà nó đang chịu trách nhiệm bao gồm cả validation, quyết định input của chính nó. Nếu không cần validate thì không cần có bước validate
3. Code trong background job vẫn là 1 service đúng chuẩn để dễ phát triển sau này.
4. Cơ chế token hiện tại chưa đúng chuẩn: User login ở nhiều devices với bộ refresh_token và access_token
5. Tách độc lập việc gọi background job (trigger sync, gửi mail, ...) sang 1 bước độc lập.
6. Không tách hàm nếu hàm ko tái sử dụng.