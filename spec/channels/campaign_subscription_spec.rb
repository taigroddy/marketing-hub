# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Turbo::StreamsChannel, type: :channel do
  let(:user) do
    User.create!(
      email: 'channel_user@example.com',
      password: 'Password123!',
      confirmed_at: Time.current
    )
  end

  let(:campaign) do
    Campaign.create!(
      user: user,
      name: 'Stream Promo',
      objective: 'OUTCOME_TRAFFIC',
      budget: 500.0,
      status: 'active'
    )
  end

  it 'successfully subscribes to the campaign stream using signed stream name' do
    signed_stream = Turbo::StreamsChannel.signed_stream_name("campaign_#{campaign.id}")
    subscribe signed_stream_name: signed_stream

    expect(subscription).to be_confirmed
    expect(subscription).to have_stream_from("campaign_#{campaign.id}")
  end

  it 'rejects subscription if signed stream name is invalid' do
    subscribe signed_stream_name: 'invalid_signed_stream_name'

    expect(subscription).to be_rejected
  end
end
