# Implementation Plan: Feedback-2 Quality & Architecture Alignment

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the updates requested in `feedback-2.md`: refactor campaign update to `Campaigns::UpdateService`, standardize all `/api/v1/*` responses to the `{ success, data, errors }` envelope, enforce multi-tenant `default_scope` from `Current.user` on `Campaign` and `PlatformAccount`, and decompose VCR cassettes into atomic reusable units to fix the 12 failing client specs with 0 mocks.

**Architecture:**
- REST API responses uniformly wrapped in `{ success: boolean, data: any, errors: any }`.
- Controller calls `Campaigns::UpdateService` (budget modification only) using block matcher.
- Models `Campaign` and `PlatformAccount` default scoped to `Current.user.id` when `Current.user.present?`; background jobs query using `.unscoped`.
- VCR cassettes modularized into atomic, reusable fixture files (`facebook_create_campaign_success.yml`, etc.) shared between client, service, and job specs.

**Tech Stack:** Rails 8.0, Dry::Transaction, Dry::Validation, ActiveRecord, VCR, WebMock, RSpec, Blueprinter.

**Spec:** [feedback-2.md](file:///Users/trucanh/Downloads/marketing-hub/feedback-2.md) and [AGENTS.md](file:///Users/trucanh/Downloads/marketing-hub/AGENTS.md)

## Global Constraints

- Zero mock/stub rule in tests (Part A, Rule 3): NO `allow(...)`, `instance_double`, `double`, or `allow_any_instance_of`.
- API endpoints under `/api/v1/*` must always return JSON with `{ "success": boolean, "data": ..., "errors": ... }`.
- Maintain test coverage $\ge 80\%$ branch coverage, 0 RSpec failures, 0 RuboCop offenses, 0 Fasterer offenses.
- Keep external 3rd-party API calls strictly outside DB transactions.

## Review Focus

1. Cross-tenant isolation with `default_scope`: User A cannot read or update User B's campaigns even if ID is known.
2. Background job query execution with `unscoped`: `SyncCampaignJob` must locate records when `Current.user` is nil without failing.
3. API response envelope consistency: every 200/201/401/404/409/422 response conforms to `{ success, data, errors }`.
4. Budget-only validation in `UpdateService`: sending unexpected attributes does not overwrite model fields or crash.
5. VCR cassette modularity: each cassette handles a single atomic HTTP interaction and contains zero leaked tokens.

---

### Task 1: Refactor to Campaigns::UpdateService & UpdateContract

**Files:**
- Rename/Modify: `app/services/campaigns/update_budget_service.rb` -> `app/services/campaigns/update_service.rb`
- Rename/Modify: `app/contracts/campaigns/update_budget_contract.rb` -> `app/contracts/campaigns/update_contract.rb`
- Modify: `app/controllers/api/v1/campaigns_controller.rb`
- Modify: `app/controllers/campaigns_controller.rb`
- Rename/Modify: `spec/services/campaigns/update_budget_service_spec.rb` -> `spec/services/campaigns/update_service_spec.rb`
- Rename/Modify: `spec/contracts/campaigns/update_budget_contract_spec.rb` -> `spec/contracts/campaigns/update_contract_spec.rb`
- Modify: `spec/requests/api/v1/campaigns_spec.rb`
- Modify: `spec/requests/campaigns_spec.rb`

**Interfaces:**
- Consumes: `full_request_params` with `:id` and `:budget`
- Produces: `Campaigns::UpdateService < ApplicationService` returning `Success(campaign: campaign)`

- [ ] **Step 1: Rename files and classes to `Campaigns::UpdateService` and `Campaigns::UpdateContract`**
- [ ] **Step 2: Update controllers to call `Campaigns::UpdateService.call(full_request_params)`**
- [ ] **Step 3: Update and run unit & request specs for campaigns update**
- [ ] **Step 4: Commit changes**

---

### Task 2: Standardize API Response Envelope ({ success, data, errors })

**Files:**
- Modify: `app/controllers/api/v1/campaigns_controller.rb`
- Modify: `app/controllers/api/v1/platform_campaigns_controller.rb`
- Modify: `app/controllers/api/v1/platform_accounts_controller.rb`
- Modify: `app/controllers/api/v1/auth_controller.rb`
- Modify: `spec/requests/api/v1/campaigns_spec.rb`
- Modify: `spec/requests/api/v1/platform_campaigns_spec.rb`
- Modify: `spec/requests/api/v1/platform_accounts_spec.rb`
- Modify: `spec/requests/api/v1/auth_spec.rb`
- Modify: `swagger/v1/swagger.yaml`

**Interfaces:**
- Produces: All JSON responses under `/api/v1/*` wrapped in `{ success: true, data: ..., errors: nil }` or `{ success: false, data: nil, errors: ... }`

- [ ] **Step 1: Update API controllers to render `{ success, data, errors }` format for all responses**
- [ ] **Step 2: Update all API request specs to assert `{ success, data, errors }` structure**
- [ ] **Step 3: Update swagger schemas in `swagger/v1/swagger.yaml`**
- [ ] **Step 4: Run request specs and verify all pass**
- [ ] **Step 5: Commit changes**

---

### Task 3: Enforce Multi-tenant default_scope on Campaign and PlatformAccount

**Files:**
- Modify: `app/models/campaign.rb`
- Modify: `app/models/platform_account.rb`
- Modify: `app/services/platform_campaigns/sync_service.rb`
- Modify: `app/jobs/sync_campaign_job.rb`
- Modify: `spec/models/campaign_spec.rb`
- Modify: `spec/models/platform_account_spec.rb`
- Test: `spec/requests/api/v1/campaigns_spec.rb`

**Interfaces:**
- Produces: `default_scope { where(user_id: Current.user.id) if Current.user.present? }` on `Campaign` and `PlatformAccount`

- [ ] **Step 1: Add unit tests for `default_scope` behavior with and without `Current.user`**
- [ ] **Step 2: Add `default_scope` to `Campaign` and `PlatformAccount`**
- [ ] **Step 3: Use `.unscoped` where needed in background sync worker**
- [ ] **Step 4: Run model specs and request specs to verify strict tenant isolation**
- [ ] **Step 5: Commit changes**

---

### Task 4: Decompose Atomic VCR Cassettes & Resolve Facebook Client Specs

**Files:**
- Create/Update: `spec/fixtures/vcr_cassettes/facebook_create_campaign_success.yml`
- Create/Update: `spec/fixtures/vcr_cassettes/facebook_create_campaign_fail.yml`
- Create/Update: `spec/fixtures/vcr_cassettes/facebook_update_campaign_success.yml`
- Create/Update: `spec/fixtures/vcr_cassettes/facebook_update_campaign_fail.yml`
- Create/Update: `spec/fixtures/vcr_cassettes/facebook_fetch_campaign_success.yml`
- Create/Update: `spec/fixtures/vcr_cassettes/facebook_fetch_campaign_fail.yml`
- Modify: `spec/clients/ad_campaign/facebook_client_spec.rb`
- Modify: `spec/services/platform_campaigns/sync_service_spec.rb`

**Interfaces:**
- Consumes: Atomic VCR cassettes recorded with real Facebook HTTP interactions
- Produces: 100% green test suite with 0 mocks and clean cassettes

- [ ] **Step 1: Generate/split atomic VCR cassettes for create, update, and fetch operations**
- [ ] **Step 2: Update `spec/clients/ad_campaign/facebook_client_spec.rb` to use matching atomic cassettes without mocks**
- [ ] **Step 3: Run full RSpec suite: verify 0 failures, 0 mocks, branch coverage >= 80%**
- [ ] **Step 4: Run RuboCop and Fasterer: verify 0 offenses**
- [ ] **Step 5: Commit changes**
