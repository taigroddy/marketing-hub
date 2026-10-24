1. Ở ApplicationController, tạo ra 1 function full_request_params để giảm code `normalized = input.respond_to?(:to_unsafe_h) ? input.to_unsafe_h : input` trong service.
2. Bỏ các function `validate_with` và `validation` trong `ApplicationService` để làm đúng tiêu chuẩn, mỗi service sẽ quản lí đúng bussiness logic mà nó đang chịu trách nhiệm bao gồm cả validation, quyết định input của chính nó. Nếu không cần validate thì không cần có bước validate.
3. Bỏ validate ở model vì bản chất layer validator (contract) sẽ làm chuyện này
4. Code trong background job vẫn là 1 service đúng chuẩn để dễ phát triển sau này.
5. Cơ chế token hiện tại chưa đúng chuẩn: User login ở nhiều devices với bộ refresh_token và access_token
6. Tách độc lập việc gọi background job (trigger sync, gửi mail, ...) sang 1 bước độc lập.
7. Không tách hàm nếu hàm ko tái sử dụng.
8. Các error code ở controller cần đúng chuẩn hơn. Ví dụ: not found khi tìm ko thấy record nhưng update không được thì phải http khác not found.
9. routes đã có constraints giới hạn platform rồi nên trong service hay validator không cần làm chuyện này nữa.
10. Phần test không được mock bất cứ gì. Dữ liệu 3rd party cũng vậy (tôi vừa bổ sung .env FB_TEST_ACCESS_TOKEN để bạn có cái run lại để lấy kết quả cho file cassettes)