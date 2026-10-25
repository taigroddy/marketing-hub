# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Auth::LoginContract do
  subject(:contract) { described_class.new }

  it 'passes with valid email and password' do
    result = contract.call(email: 'user@example.com', password: 'Password123!')
    expect(result).to be_success
  end

  it 'fails when email is empty' do
    result = contract.call(email: '', password: 'Password123!')
    expect(result).to be_failure
    expect(result.errors[:email]).to be_present
  end

  it 'fails when email format is invalid' do
    result = contract.call(email: 'not-an-email', password: 'Password123!')
    expect(result).to be_failure
    expect(result.errors[:email]).to include(I18n.t('dry_validation.errors.rules.email.invalid'))
  end

  it 'fails when password is empty' do
    result = contract.call(email: 'user@example.com', password: '')
    expect(result).to be_failure
    expect(result.errors[:password]).to be_present
  end
end
