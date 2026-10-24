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
  end
end
