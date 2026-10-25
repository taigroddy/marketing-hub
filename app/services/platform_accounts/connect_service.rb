# frozen_string_literal: true

module PlatformAccounts
  class ConnectService < ApplicationService
    step :validation
    step :save_platform_account

    protected

    def validation(input)
      result = PlatformAccounts::ConnectContract.new.call(input)
      if result.success?
        Success(result.to_h)
      else
        Failure(result.errors.to_h)
      end
    end

    def save_platform_account(input)
      return Failure(error: "Google platform integration coming soon") if input[:platform].to_s.downcase == "google"

      user = Current.user
      client = Clients::OAuth::FacebookClient.new

      exchange_result = client.exchange_code(code: input[:code], redirect_uri: input[:redirect_uri])
      return Failure(exchange_result.failure) if exchange_result.failure?

      token_data = exchange_result.value!
      access_token = token_data[:access_token]
      expires_in = token_data[:expires_in]
      token_expires_at = expires_in ? Time.current + expires_in.to_i.seconds : nil

      account_id = input[:account_id]
      name = input[:name]

      if account_id.blank? && client.respond_to?(:fetch_ad_accounts)
        ad_res = client.fetch_ad_accounts(access_token)
        if ad_res.success?
          accounts = ad_res.value![:data]
          if accounts.is_a?(Array) && accounts.first
            acc = accounts.first.transform_keys(&:to_s)
            account_id = acc["account_id"] || acc["id"]
            name ||= acc["name"]
          end
        end
      end

      if account_id.blank? && client.respond_to?(:fetch_user_info)
        user_res = client.fetch_user_info(access_token)
        if user_res.success?
          uinfo = user_res.value!.transform_keys(&:to_s)
          account_id = uinfo["id"]
          name ||= uinfo["name"]
        end
      end

      account_id ||= token_data[:account_id] || "act_#{user&.id}"
      name ||= token_data[:name] || "Facebook Ad Account"

      account = PlatformAccount::Facebook.find_or_initialize_by(
        account_id: account_id.to_s
      )
      account.user = user if user

      account.assign_attributes(
        name: name,
        access_token: access_token,
        refresh_token: token_data[:refresh_token] || account.refresh_token,
        token_expires_at: token_expires_at,
        refresh_token_expires_at: token_data[:refresh_token_expires_at] || account.refresh_token_expires_at,
        status: "connected"
      )

      if account.save
        Success(platform_account: account)
      else
        Failure(account.errors.to_hash)
      end
    end
  end
end
