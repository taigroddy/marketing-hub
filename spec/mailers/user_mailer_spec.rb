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
      expect(mail.subject).to eq(I18n.t('mailers.user_mailer.confirmation_subject'))
      expect(mail.to).to eq([ 'confirm-me@example.com' ])
      expect(mail.from).to eq([ 'from@example.com' ])
    end

    it 'renders the confirmation URL in the body' do
      expect(mail.text_part.body.decoded).to include('http://marketing.localhost/confirm_email/test-token-456')
      expect(mail.html_part.body.decoded).to include(I18n.t('mailers.user_mailer.confirm_button'))
    end
  end
end
