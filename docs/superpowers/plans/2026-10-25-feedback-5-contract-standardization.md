# Implementation Plan: 100% Dry::Validation Contract Standardization (Feedback 5)

## 1. Overview & Context

This implementation enforces the Contract boundary and eliminates defensive parameter parsing in the Service layer:
1. **Contract as the Single Source of Truth:**
   - Define missing contracts:
     - `PlatformCampaigns::PublishContract`
     - `PlatformCampaigns::ResyncContract`
   - All input validation rules (types, formats, requirements) live exclusively in Contracts.
2. **Purge Defensive Parameter Parsing in Services:**
   - Standardize all `validation` steps across Services to the clean 3-line pattern:
     ```ruby
     def validation(input)
       result = SomeContract.new.call(input)
       result.success? ? Success(result.to_h) : Failure(result.errors.to_h)
     end
     ```
   - Eliminate all manual unwrapping (`[:campaign]`, `[:platform_campaign]`), manual string trimming, manual singular/plural checks (`platform_account_id` vs `platform_account_ids`), and manual hash symbolizing in services.
3. **Frontend / API Client Contract Adherence:**
   - Ensure UI forms and API requests pass flat, clean payload attributes matching the contracts.

---

## 2. Tasks & Step-by-Step Breakdown

### Task 1: Create Missing Contracts
- Create `app/contracts/platform_campaigns/publish_contract.rb`:
  - `id` / `campaign_id`: integer
  - `platform`: string, included in %w[facebook google]
  - `platform_account_ids`: array of integers, min size 1
- Create `app/contracts/platform_campaigns/resync_contract.rb`:
  - `id` / `campaign_id`: integer
  - `platform`: string, included in %w[facebook google]
  - `platform_campaign_id`: optional integer
  - `force`: optional boolean
- Add contract specs in `spec/contracts/platform_campaigns/`.

### Task 2: Refactor Service `validation` Steps
- `Campaigns::CreateService`: simplify `validation` to call `Campaigns::CreateContract.new.call(input)`.
- `Campaigns::UpdateService`: simplify `validation` to call `Campaigns::UpdateContract.new.call(input)`.
- `PlatformCampaigns::PublishService`: replace ad-hoc validation with `PlatformCampaigns::PublishContract`.
- `PlatformCampaigns::ResyncService`: replace ad-hoc validation with `PlatformCampaigns::ResyncContract`.
- `Auth::RegisterService`: remove raw unwrapping and manual string manipulation; call `Auth::RegisterContract.new.call(input)`.
- `Auth::LoginService`: remove manual strip and symbolization; call `Auth::LoginContract.new.call(input)`.
- `PlatformAccounts::ConnectService`: simplify `validation` to call `PlatformAccounts::ConnectContract.new.call(input)`.

### Task 3: Quality Gates & Verification
- Run complete test suite: `docker compose exec -T web bundle exec rspec` (Must be 0 failures, 0 mocks, branch coverage >= 80%).
- Run `docker compose exec -T web bundle exec rubocop` (0 offenses).
- Run `docker compose exec -T web bundle exec fasterer` (0 offenses).
