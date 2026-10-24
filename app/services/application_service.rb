# frozen_string_literal: true

require "dry/transaction"
require "dry/monads"

class ApplicationService
  include Dry::Transaction
  include Dry::Monads[:result, :do]

  class << self
    def call(*args, **kwargs, &block)
      if kwargs.empty?
        new.call(*args, &block)
      else
        new.call(*args, **kwargs, &block)
      end
    end

    def contract(klass = nil)
      if klass
        @contract = klass
      else
        @contract
      end
    end
  end

  def validate_with(contract_or_class, input)
    contract = contract_or_class.is_a?(Class) ? contract_or_class.new : contract_or_class
    result = contract.call(input)

    if result.success?
      Success(result.to_h)
    else
      Failure(result.errors.to_h)
    end
  end

  def validation(input)
    if self.class.contract
      validate_with(self.class.contract, input)
    else
      Success(input)
    end
  end
end
