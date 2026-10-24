# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationService do
  let(:two_step_service_class) do
    Class.new(ApplicationService) do
      step :step_one
      step :step_two

      def step_one(input)
        if input[:fail_at] == :step_one
          Failure(:error_one)
        else
          Success(input.merge(step_one: true))
        end
      end

      def step_two(input)
        if input[:fail_at] == :step_two
          Failure(:error_two)
        else
          Success(input.merge(step_two: true))
        end
      end
    end
  end

  describe 'architecture and interface' do
    it 'does not expose class-level contract macro' do
      expect(described_class).not_to respond_to(:contract)
    end

    it 'does not expose instance-level validate_with or validation helpers' do
      instance = described_class.new
      expect(instance).not_to respond_to(:validate_with)
      expect(instance).not_to respond_to(:validation)
    end
  end

  describe '.call' do
    context 'without a block' do
      it 'returns Success with output when all steps succeed' do
        result = two_step_service_class.call(name: 'Alice')

        expect(result).to be_success
        expect(result.value!).to eq(name: 'Alice', step_one: true, step_two: true)
      end

      it 'returns Failure when first step fails' do
        result = two_step_service_class.call(name: 'Alice', fail_at: :step_one)

        expect(result).to be_failure
        expect(result.failure).to eq(:error_one)
      end

      it 'returns Failure when second step fails' do
        result = two_step_service_class.call(name: 'Alice', fail_at: :step_two)

        expect(result).to be_failure
        expect(result.failure).to eq(:error_two)
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

      it 'works with keyword arguments' do
        kwargs_service = Class.new(ApplicationService) do
          step :process

          def process(input)
            Success(a: input[:a], b: input[:b])
          end
        end

        result = kwargs_service.call(a: 10, b: 20)
        expect(result).to be_success
        expect(result.value!).to eq(a: 10, b: 20)
      end
    end

    context 'with a matcher block' do
      it 'invokes m.success block when all steps succeed' do
        yielded_result = nil
        step_one_called = false
        general_failure_called = false

        two_step_service_class.call(name: 'Alice') do |m|
          m.success do |result|
            yielded_result = result
          end

          m.failure(:step_one) do |_err|
            step_one_called = true
          end

          m.failure do |_err|
            general_failure_called = true
          end
        end

        expect(yielded_result).to eq(name: 'Alice', step_one: true, step_two: true)
        expect(step_one_called).to be false
        expect(general_failure_called).to be false
      end

      it 'invokes m.failure(:step_name) matching the failing step' do
        success_called = false
        step_one_error = nil
        general_failure_called = false

        two_step_service_class.call(name: 'Alice', fail_at: :step_one) do |m|
          m.success do |_result|
            success_called = true
          end

          m.failure(:step_one) do |err|
            step_one_error = err
          end

          m.failure do |_err|
            general_failure_called = true
          end
        end

        expect(success_called).to be false
        expect(step_one_error).to eq(:error_one)
        expect(general_failure_called).to be false
      end

      it 'invokes catch-all m.failure block when step failure is not explicitly matched' do
        success_called = false
        step_one_called = false
        general_error = nil

        two_step_service_class.call(name: 'Alice', fail_at: :step_two) do |m|
          m.success do |_result|
            success_called = true
          end

          m.failure(:step_one) do |_err|
            step_one_called = true
          end

          m.failure do |err|
            general_error = err
          end
        end

        expect(success_called).to be false
        expect(step_one_called).to be false
        expect(general_error).to eq(:error_two)
      end
    end
  end
end
