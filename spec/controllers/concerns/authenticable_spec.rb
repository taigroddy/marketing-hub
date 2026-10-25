# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Authenticable do
  describe '.encode_jwt and .decode_jwt' do
    it 'encodes and decodes payload with indifferent access' do
      token = described_class.encode_jwt({ user_id: 42, role: 'admin' })
      expect(token).to be_a(String)

      decoded = described_class.decode_jwt(token)
      expect(decoded[:user_id]).to eq(42)
      expect(decoded['user_id']).to eq(42)
      expect(decoded[:role]).to eq('admin')
      expect(decoded[:exp]).to be_present
    end

    it 'returns nil for nil or blank token' do
      expect(described_class.decode_jwt(nil)).to be_nil
      expect(described_class.decode_jwt('')).to be_nil
      expect(described_class.decode_jwt('   ')).to be_nil
    end

    it 'returns nil for invalid/tampered token or input raising ArgumentError' do
      expect(described_class.decode_jwt('invalid.jwt.token')).to be_nil
      expect(described_class.decode_jwt(12345)).to be_nil
    end

    it 'returns nil for expired token' do
      expired_token = described_class.encode_jwt({ user_id: 42 }, 1.hour.ago)
      expect(described_class.decode_jwt(expired_token)).to be_nil
    end

    it 'preserves existing exp in payload if already provided' do
      custom_exp = 2.hours.from_now.to_i
      token = described_class.encode_jwt({ user_id: 99, exp: custom_exp })
      decoded = described_class.decode_jwt(token)
      expect(decoded[:exp]).to eq(custom_exp)
    end

    it 'uses JWT_SECRET from ENV if present' do
      orig_secret = ENV['JWT_SECRET']
      begin
        ENV['JWT_SECRET'] = 'test_jwt_custom_secret'
        expect(described_class.jwt_secret_key).to eq('test_jwt_custom_secret')
      ensure
        ENV['JWT_SECRET'] = orig_secret
      end
    end
  end

  describe 'class methods inclusion' do
    let(:dummy_class) do
      Class.new do
        include Authenticable
      end
    end

    it 'provides encode_jwt and decode_jwt as class methods' do
      token = dummy_class.encode_jwt({ user_id: 200 })
      expect(token).to be_a(String)
      decoded = dummy_class.decode_jwt(token)
      expect(decoded[:user_id]).to eq(200)
    end
  end
end
