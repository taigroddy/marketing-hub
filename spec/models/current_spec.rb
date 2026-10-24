# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Current do
  after do
    Current.reset
  end

  it 'inherits from ActiveSupport::CurrentAttributes' do
    expect(Current < ActiveSupport::CurrentAttributes).to be true
  end

  it 'allows setting and reading user attribute' do
    user = { id: 1, email: 'user@example.com' }
    Current.user = user
    expect(Current.user).to eq(user)
  end

  it 'resets attributes cleanly' do
    Current.user = { id: 1 }
    Current.reset
    expect(Current.user).to be_nil
  end
end
