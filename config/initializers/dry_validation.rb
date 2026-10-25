# frozen_string_literal: true

require "dry/schema/constants"
require "dry/validation/constants"

I18n.load_path += [
  Dry::Schema::DEFAULT_MESSAGES_PATH.to_s,
  Dry::Validation::DEFAULT_ERRORS_PATH.to_s
]
