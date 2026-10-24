# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserMailer, type: :mailer do
  describe '#confirmation_email' do
    let(:user) do
      User.create!(
        email: 'confirm-me@example.com',
        password: 'Password123!',
        confirmation_token: 'test-token-456'
      )
    end
    let(:mail) { described_class.confirmation_email(user) }

    it 'renders the headers' do
      expect(mail.subject).to eq('Confirm your email address')
      expect(mail.to).to eq([ 'confirm-me@example.com' ])
      expect(mail.from).to eq([ 'from@example.com' ])
    end

    it 'renders the confirmation URL in the body' do
      expect(mail.body.encoded).to include('http://marketing.localhost/confirm_email/test-token-456')
      expect(mail.body.encoded).to include('Confirm My Email')
    end
  end
end
