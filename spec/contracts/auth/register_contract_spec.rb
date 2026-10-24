# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Auth::RegisterContract do
  subject(:contract) { described_class.new }

  it 'passes with valid email and password' do
    result = contract.call(email: 'user@example.com', password: 'Password123!', password_confirmation: 'Password123!')
    expect(result).to be_success
  end

  it 'passes when password_confirmation is omitted or nil' do
    result = contract.call(email: 'user@example.com', password: 'Password123!')
    expect(result).to be_success
  end

  it 'fails when email is missing or empty' do
    result = contract.call(email: '', password: 'Password123!')
    expect(result).to be_failure
    expect(result.errors[:email]).to be_present
  end

  it 'fails when email format is invalid' do
    result = contract.call(email: 'invalid-email', password: 'Password123!')
    expect(result).to be_failure
    expect(result.errors[:email]).to include('is invalid')
  end

  it 'fails when password is too short' do
    result = contract.call(email: 'user@example.com', password: '123')
    expect(result).to be_failure
    expect(result.errors[:password]).to be_present
  end

  it 'fails when password_confirmation does not match password' do
    result = contract.call(
      email: 'user@example.com',
      password: 'Password123!',
      password_confirmation: 'DifferentPassword'
    )
    expect(result).to be_failure
    expect(result.errors[:password_confirmation]).to include('must match password')
  end
end
