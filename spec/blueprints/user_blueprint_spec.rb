# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserBlueprint do
  let(:user) do
    User.create!(
      email: 'blueprint@example.com',
      password: 'Password123!',
      confirmation_token: 'secret-token',
      confirmed_at: Time.zone.parse('2026-10-24 12:00:00 UTC')
    )
  end

  describe '.render_as_hash' do
    it 'serializes expected user fields and excludes sensitive data' do
      hash = described_class.render_as_hash(user)

      expect(hash).to include(
        id: user.id,
        email: 'blueprint@example.com',
        confirmed_at: user.confirmed_at
      )
      expect(hash).not_to have_key(:password_digest)
      expect(hash).not_to have_key(:confirmation_token)
    end
  end
end
