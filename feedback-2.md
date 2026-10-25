Rules cố định (`.gemini/rules/project_guidelines.md` hoặc `AGENTS.md`) để mọi agent sau này luôn tuân thủ:
1. Chuẩn hóa bộ quy tắc kiến trúc toàn diện (Layering Controller - Service - Contract - Job / Model)
2. Quy tắc không tách hàm vụn vặt (tuân thủ DRY)
3. Không mock trong test nếu không còn cách khác nên bỏ dở và quay lại hỏi tôi khi kết thúc.
4. Format API chỉ cho phép JSON.
5. Format response API nên đúng chuẩn:
```
{
    "success": true|false,
    "data": ...,
    "errors": ...,
}
```

Feedbacks:
1. endpoint cho update campaign nên là UpdateService (và hiện tại chỉ allow update Budget)
2. Để tránh bị issue non-tenant (user này có thể truy cập user kia) hãy để scope default của campaign, platform_campaign, platform_account query từ current_user (khi nào cần lấy hết thì Dev sẽ tự unscope để đảm bảo tính chính chủ data)
3. Tách nhỏ cassettes VCR để có thể tái sử dụng ở nhiều chỗ. Ví dụ: trong `app/clients/ad_campaign/facebook_client.rb`, sẽ có `facebook_create_campaign`, `facebook_create_campaign_fail`, ...
