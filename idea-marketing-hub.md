Phân tích tài liệu tổng hợp về marketing hub:

1. Idea: 1 web Application cho phép người dùng tạo ads campaign và publish lên các platform ads khác như Facebook, Google ở mức demo ở local;
2. Techstack:
- BE: Viết API với rails 8 và Ruby 3.x
- DB: Dùng postgresql
- Websocket/Caching: Redis
- FE: tận dụng view của rails và tương tác với BE qua API
- Tool development:
+ Docker compose cho set up local với các service tương ứng. Thêm mailchimp cho host mail local và traefik cho set úp domain local như marketing.localhost, mailchimp.localhost
+ Gem development: byebug, rspec, vcr (record 3rd party), rubocop, fasterer, simple coverage và rswag
+ Gem structure: dry-validation, dry-transaction, dry-monals, turbo-stream

3. Code Convention:
- Layer level: Controller > Service (dry-transaction + dry-monals) > Validation/Contract (dry-validation) > Model. Các layer phải tuân thủ chỉ gọi được layer cấp dưới, không gọi cùng cấp hoặc trên cấp. Ngoại lệ với Background Job được call service và được call lại service trigger:
+ Controller: Xử lý authorize (current_user qua jwt token) và format response qua sử dụng bluesprint; bypass request params mà không cần tiền xử lí để service tự validation input của chính service; Tuyệt đối ko xử lí business logic ở đây
+ Service: nơi xử lí bussiness chính với các group function (protect, private), input sẽ được validate thông qua step validation. Các protect functions sẽ là flow chính (tương ứng với các khai báo step), các private functions sẽ xử lí phần riêng biệt cho việc parse/convert data của chính service. Với các private functions, giảm tối thiểu các function trong group này để tránh việc tách function nhỏ function không cần thiết.
+ Model: Giữ nguyên vai trò trong rails với quy tắc không dùng callback để trigger job.
- Submit DB transaction: Không gọi 3rd party, sử dụng upsert cho create và update nhiều thay cho loop.
- Unit test: branch coverage >= 80%. Luôn sử dụng VCR (record lần đầu) thay cho webmock để tránh data ko thật.
- Format của code như sau:
```
# controler
def create
    SomethingService.call do |m|
        m.success do |r|
            ...
        end

        m.failure(:validation) do |error|
            ...
        end

        m.failure do |error|
            ...
        end
    end
end

# service
class SomethingService < ApplicationService
    step :validation # validate input từ request
    step :check_resource # dành cho các validation kiểm tra qua query DB
    step ....
end
```

4. Bussiness flow:
Functional:
- Màn hình login / đăng kí / forget password. Đối với đăng kí, sau khi xong action thì sẻ gửi mail xác nhận, khi bấm vào mail xác nhận thì auto đăng nhập.
- Màn hình chính (sau khi login thành công) với các sections:
+ Section 1: Hiện thỉ list platform accounts thông qua Oauth2 cấp quyền của các platforms (có UI empty khi chưa có accounts nào với liên kết mới). Action `liên kết mới` sẽ show 1 popup cho phép chọn platform để kết nối, hiện tại mở facebook và google. Với option google sẽ bị disable với hint sẽ release sắp tới.
+ Section 2: Hiển thị list campaign system (có UI empty với action tạo campaign đầu tiên). Action `Tạo mới` sẽ redirect đến form tạo campaign. Item trong list có action `view detail`
- Màn hình tạo campaign: Chỉ cần dừng mức tạo campaign với các thông tin tối thiểu (tên, mục tiêu, budget).
- Màn hình update campaign: disable cái input và chỉ cho phép chỉnh sửa budget
- Màn hình details campaign với các sections:
+ Section 1: thông tin tối thiểu của 1 campaigns và nút cho pháp chỉnh sửa
+ Section 2: Hiển thị list platform accounts với status tương ứng để biết là đã publish campaign lên platform với platform account tương ứng. Các item trong list có check box và nút sync to platform ở dưới. Disable check box nếu đã dùng account đó để publish campaign.
+ Section 3: Hiển thị danh sách liên kết giữa campaign system và platform campaigns (thông qua account nào). Ở danh sách này, mỗi item sẽ có nút re-sync nếu thông tin campaign system và ads campaign sai lệch (thông qua col synced_at)

Non-functional:
- Security: Phải xét yếu tố tenant khi load resources; Phải xét đến encrypt privacy data (ví dụ: token từ platform);
- Performance: N+1 query
- Realtime notication và đồng bộ dữ liệu ở màn hình campaign details với turbo-stream và redis.


For agent rules and skills:
1. Ưu tiên dùng các rails script (scaffold, migration, ..) để tạo các code cần thiết, tránh việc viết và tạo lại files
2. Các tài liệu phải nằm trong folder này và viết lại đầy đủ.
3. Không cài đặt gì thêm trên máy mà chỉ chạy tất cả trên docker container (theo nguyên tắc tách biệt môi trường).