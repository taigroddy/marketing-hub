# frozen_string_literal: true

class SyncCampaignJob < ApplicationJob
  queue_as :default

  def perform(platform_campaign_id)
    platform_campaign = PlatformCampaign.find_by(id: platform_campaign_id)
    return unless platform_campaign

    campaign = platform_campaign.campaign
    account = platform_campaign.platform_account

    begin
      result = sync_with_platform(platform_campaign, campaign, account)
      persist_sync_result(platform_campaign, result)
    rescue StandardError => e
      persist_error_result(platform_campaign, e.message)
    ensure
      broadcast_updates(campaign)
    end
  end

  private

  def broadcast_updates(campaign)
    return unless campaign

    reloaded_campaign = campaign.reload
    connected_accounts = reloaded_campaign.user.platform_accounts.connected
    ordered_platform_campaigns = reloaded_campaign.platform_campaigns.includes(:platform_account).order(created_at: :desc)

    Turbo::StreamsChannel.broadcast_replace_to(
      "campaign_#{reloaded_campaign.id}",
      target: "platform_accounts_section",
      partial: "campaigns/platform_accounts_section",
      locals: {
        campaign: reloaded_campaign,
        platform_accounts: connected_accounts,
        platform_campaigns: ordered_platform_campaigns
      }
    )

    Turbo::StreamsChannel.broadcast_replace_to(
      "campaign_#{reloaded_campaign.id}",
      target: "platform_campaigns_section",
      partial: "campaigns/platform_campaigns_section",
      locals: {
        campaign: reloaded_campaign,
        platform_campaigns: ordered_platform_campaigns
      }
    )
  end

  def sync_with_platform(platform_campaign, campaign, account)
    if inside_db_transaction?
      raise "Violation: 3rd party API called inside DB transaction"
    end

    platform_name = account.platform_name.to_s.downcase

    case platform_name
    when "facebook"
      sync_facebook(platform_campaign, campaign, account)
    when "google"
      Dry::Monads::Failure(error: "Google platform integration coming soon")
    else
      Dry::Monads::Failure(error: "Unsupported platform: #{platform_name}")
    end
  end

  def sync_facebook(platform_campaign, campaign, account)
    client = Clients::AdCampaign::FacebookClient.new(
      access_token: account.access_token,
      account_id: account.account_id
    )

    if platform_campaign.external_campaign_id.present?
      client.update_campaign(
        campaign_id: platform_campaign.external_campaign_id,
        budget: campaign.budget,
        name: campaign.name
      )
    else
      client.create_campaign(
        name: campaign.name,
        objective: campaign.objective,
        budget: campaign.budget,
        account_id: account.account_id
      )
    end
  end

  def persist_sync_result(platform_campaign, result)
    now = Time.current

    if result.success?
      data = result.value!
      external_id = data[:id] || platform_campaign.external_campaign_id
      PlatformCampaign.upsert(
        {
          id: platform_campaign.id,
          campaign_id: platform_campaign.campaign_id,
          platform_account_id: platform_campaign.platform_account_id,
          external_campaign_id: external_id,
          sync_status: "synced",
          synced_at: now,
          last_error_message: nil,
          updated_at: now
        },
        unique_by: :id
      )
    else
      error_message = extract_error_message(result.failure)
      PlatformCampaign.upsert(
        {
          id: platform_campaign.id,
          campaign_id: platform_campaign.campaign_id,
          platform_account_id: platform_campaign.platform_account_id,
          external_campaign_id: platform_campaign.external_campaign_id,
          sync_status: "failed",
          last_error_message: error_message,
          updated_at: now
        },
        unique_by: :id
      )
    end
  end

  def persist_error_result(platform_campaign, error_message)
    now = Time.current
    PlatformCampaign.upsert(
      {
        id: platform_campaign.id,
        campaign_id: platform_campaign.campaign_id,
        platform_account_id: platform_campaign.platform_account_id,
        external_campaign_id: platform_campaign.external_campaign_id,
        sync_status: "failed",
        last_error_message: error_message,
        updated_at: now
      },
      unique_by: :id
    )
  end

  def extract_error_message(failure)
    if failure.is_a?(Hash)
      failure[:error] || failure.values.flatten.join(", ")
    else
      failure.to_s
    end
  end

  def inside_db_transaction?
    threshold = Rails.env.test? ? 1 : 0
    ActiveRecord::Base.connection.open_transactions > threshold
  end
end
