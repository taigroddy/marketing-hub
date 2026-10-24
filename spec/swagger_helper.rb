# frozen_string_literal: true

require "rails_helper"

RSpec.configure do |config|
  # Specify a root folder where Swagger JSON/YAML files are generated
  config.openapi_root = Rails.root.join("swagger").to_s

  # Define one or more Swagger documents and provide global metadata for each one
  config.openapi_specs = {
    "v1/swagger.yaml" => {
      openapi: "3.0.1",
      info: {
        title: "Marketing Hub API",
        version: "v1",
        description: "Omnichannel Marketing Hub REST API documentation for authentication, ad campaigns, and platform integrations."
      },
      paths: {},
      servers: [
        {
          url: "http://{defaultHost}",
          description: "Local development server",
          variables: {
            defaultHost: {
              default: "marketing.localhost"
            }
          }
        },
        {
          url: "http://localhost:3000",
          description: "Direct Puma server"
        }
      ],
      components: {
        securitySchemes: {
          bearerAuth: {
            type: :http,
            scheme: :bearer,
            bearerFormat: :JWT,
            description: "Provide JWT token in Authorization header: Bearer <token>"
          }
        }
      }
    }
  }

  config.openapi_format = :yaml
end
