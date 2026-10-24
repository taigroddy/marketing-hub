# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationService do
  # Define test contracts and services to test ApplicationService behavior
  let(:test_contract_class) do
    Class.new(ApplicationContract) do
      params do
        required(:name).filled(:string)
        required(:email).filled(:string)
        optional(:forbidden).maybe(:bool)
      end
    end
  end

  let(:service_class) do
    contract_class = test_contract_class

    Class.new(ApplicationService) do
      contract contract_class
      step :validation
      step :check_resource
      step :process

      def check_resource(input)
        if input[:forbidden]
          Failure(:forbidden_access)
        else
          Success(input)
        end
      end

      def process(input)
        Success(message: "Hello #{input[:name]}", email: input[:email])
      end
    end
  end

  let(:manual_validation_service_class) do
    contract_class = test_contract_class

    Class.new(ApplicationService) do
      step :validation
      step :process

      define_method(:validation) do |input|
        validate_with(contract_class, input)
      end

      def process(input)
        Success(result: "Processed #{input[:name]}")
      end
    end
  end

  describe '.call' do
    context 'without a block' do
      it 'returns Success with output when all steps succeed' do
        result = service_class.call(name: 'Alice', email: 'alice@example.com')

        expect(result).to be_success
        expect(result.value!).to eq(message: 'Hello Alice', email: 'alice@example.com')
      end

      it 'returns Failure with errors when contract validation fails' do
        result = service_class.call(name: '', email: 'alice@example.com')

        expect(result).to be_failure
        expect(result.failure).to eq(name: [ 'must be filled' ])
      end

      it 'returns Failure when a non-validation step fails' do
        result = service_class.call(name: 'Alice', email: 'alice@example.com', forbidden: true)

        expect(result).to be_failure
        expect(result.failure).to eq(:forbidden_access)
      end

      it 'works with manual validate_with helper using contract instance' do
        contract_instance = test_contract_class.new
        instance_validation_service = Class.new(ApplicationService) do
          step :validation
          step :process

          define_method(:validation) do |input|
            validate_with(contract_instance, input)
          end

          def process(input)
            Success(result: "Instance #{input[:name]}")
          end
        end

        success_result = instance_validation_service.call(name: 'Charlie', email: 'charlie@example.com')
        expect(success_result).to be_success
        expect(success_result.value!).to eq(result: 'Instance Charlie')
      end

      it 'works with positional argument without kwargs' do
        positional_service = Class.new(ApplicationService) do
          step :process

          def process(input)
            Success("Received #{input}")
          end
        end

        result = positional_service.call('positional_data')
        expect(result).to be_success
        expect(result.value!).to eq('Received positional_data')
      end

      it 'handles ActionController::Parameters input without raising ArgumentError' do
        params = ActionController::Parameters.new(name: 'Dave', email: 'dave@example.com')
        result = service_class.call(params)

        expect(result).to be_success
        expect(result.value!).to eq(message: 'Hello Dave', email: 'dave@example.com')
      end


    end

    context 'with a matcher block' do
      it 'invokes m.success block when successful' do
        yielded_result = nil
        validation_called = false
        general_failure_called = false

        service_class.call(name: 'Alice', email: 'alice@example.com') do |m|
          m.success do |result|
            yielded_result = result
          end

          m.failure(:validation) do |_err|
            validation_called = true
          end

          m.failure do |_err|
            general_failure_called = true
          end
        end

        expect(yielded_result).to eq(message: 'Hello Alice', email: 'alice@example.com')
        expect(validation_called).to be false
        expect(general_failure_called).to be false
      end

      it 'invokes m.failure(:validation) block when validation step fails' do
        success_called = false
        validation_error = nil
        general_failure_called = false

        service_class.call(name: '', email: 'alice@example.com') do |m|
          m.success do |_result|
            success_called = true
          end

          m.failure(:validation) do |err|
            validation_error = err
          end

          m.failure do |_err|
            general_failure_called = true
          end
        end

        expect(success_called).to be false
        expect(validation_error).to eq(name: [ 'must be filled' ])
        expect(general_failure_called).to be false
      end

      it 'invokes m.failure catch-all block when a later step fails' do
        success_called = false
        validation_called = false
        general_error = nil

        service_class.call(name: 'Alice', email: 'alice@example.com', forbidden: true) do |m|
          m.success do |_result|
            success_called = true
          end

          m.failure(:validation) do |_err|
            validation_called = true
          end

          m.failure do |err|
            general_error = err
          end
        end

        expect(success_called).to be false
        expect(validation_called).to be false
        expect(general_error).to eq(:forbidden_access)
      end
    end

    context 'when service has no contract specified' do
      let(:plain_service_class) do
        Class.new(ApplicationService) do
          step :validation
          step :process

          def process(input)
            Success(input: input)
          end
        end
      end

      it 'passes validation by default and continues execution' do
        result = plain_service_class.call(test: 'data')
        expect(result).to be_success
        expect(result.value!).to eq(input: { test: 'data' })
      end
    end

    context 'with keyword arguments delegation' do
      let(:kwargs_service_class) do
        Class.new(ApplicationService) do
          step :process

          def process(input)
            Success(a: input[:a], b: input[:b])
          end
        end
      end

      it 'passes kwargs correctly' do
        result = kwargs_service_class.call(a: 1, b: 2)
        expect(result).to be_success
        expect(result.value!).to eq(a: 1, b: 2)
      end
    end
  end
end
