# Implementation Plan: Unconditional Multi-Tenant Default Scope & Query Clean-up (Feedback 4)

## 1. Overview & Context

This implementation addresses the feedback regarding multi-tenant query cleanliness and default_scope strictness:
1. **Unconditional default_scope:** Change `default_scope { where(user_id: Current.user.id) if Current.user.present? }` to `default_scope { where(user_id: Current.user&.id) }` on `Campaign` and `PlatformAccount`.
   - When `Current.user` is present, queries are automatically isolated to `Current.user.id`.
   - When `Current.user` is nil, queries automatically resolve to `WHERE user_id IS NULL` (returning empty array, preventing data leaks).
   - Background tasks or unscoped queries must explicitly call `.unscoped`.
2. **Purge redundant `Current.user.*` calls:** Replace all redundant chained queries like `Current.user.campaigns` and `Current.user.platform_accounts` across Controllers and Services with direct, idiomatic model queries (`Campaign.all`, `Campaign.find_by`, `Campaign.new`, `PlatformAccount.connected`, `PlatformAccount.all`).
3. **Service layer integration:** In services, ensure `Current.user ||= input[:user] if input[:user]` is assigned in `check_resource` so all subsequent model queries seamlessly inherit the default scope.

---

## 2. Tasks & Step-by-Step Breakdown

### Task 1: Update Models & Guidelines
- In `app/models/campaign.rb`: set `default_scope { where(user_id: Current.user&.id) }`.
- In `app/models/platform_account.rb`: set `default_scope { where(user_id: Current.user&.id) }`.
- Update `AGENTS.md` and `.gemini/rules/project_guidelines.md` to document the unconditional default scope.

### Task 2: Purge Redundant `Current.user.*` in Controllers
- `CampaignsController`:
  - `Campaign.order(created_at: :desc)`
  - `Campaign.find_by(id: params[:id])`
  - `PlatformAccount.connected`
  - `Campaign.new`
- `Api::V1::CampaignsController`:
  - `Campaign.order(created_at: :desc)`
  - `Campaign.find_by(id: params[:id])`
- `Api::V1::PlatformAccountsController`:
  - `PlatformAccount.order(created_at: :desc)`
- `DashboardController`:
  - `PlatformAccount.order(created_at: :desc)`
  - `Campaign.order(created_at: :desc)`

### Task 3: Purge Redundant `Current.user.*` in Services
- `Campaigns::CreateService`:
  - Set `Current.user ||= input[:user] if input[:user]`
  - Use `Campaign.new(...)`
- `Campaigns::UpdateService`:
  - Set `Current.user ||= input[:user] if input[:user]`
  - Use `Campaign.find_by(id: input[:id])`
- `PlatformCampaigns::PublishService`:
  - Set `Current.user ||= input[:user] if input[:user]`
  - Use `Campaign.find_by(id: input[:campaign_id])`
  - Use `PlatformAccount.where(id: input[:platform_account_ids])`
- `PlatformCampaigns::ResyncService`:
  - Set `Current.user ||= input[:user] if input[:user]`
  - Use `Campaign.find_by(id: input[:campaign_id])`
- `PlatformAccounts::ConnectService`:
  - Set `Current.user ||= input[:user] if input[:user]`

### Task 4: Update Specs & Quality Gates
- Update `spec/models/campaign_spec.rb` and `spec/models/platform_account_spec.rb` to assert that when `Current.user` is nil, queries return empty (`[]`) unless `.unscoped` is used.
- Run complete test suite: `docker compose exec -T web bundle exec rspec` (Must be 0 failures, 0 mocks, branch coverage >= 80%).
- Run `docker compose exec -T web bundle exec rubocop` (0 offenses).
- Run `docker compose exec -T web bundle exec fasterer` (0 offenses).
