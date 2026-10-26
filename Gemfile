source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.0.5", ">= 8.0.5.1"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft", "~> 1.3"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"
# Pin json to < 3.0 for Rails 8 ActiveSupport compatibility
gem "json", "< 3.0"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", "~> 8.0"
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails", "~> 2.2"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails", "~> 2.0"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails", "~> 1.3"
# Use Tailwind CSS [https://github.com/rails/tailwindcss-rails]
gem "tailwindcss-rails", "~> 4.6"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder", "~> 2.15"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
gem "bcrypt", "~> 3.1.7"

# Business logic, validation, serialization, and auth
gem "dry-transaction", "~> 0.16.0"
gem "dry-monads", "~> 1.11"
gem "dry-validation", "~> 1.11"
gem "blueprinter", "~> 1.3"
gem "jwt", "~> 3.3"
gem "facebookbusiness", "~> 26.0"

# Background jobs and caching
gem "sidekiq", "~> 8.1"
gem "redis", ">= 4.0", "< 6.0"

# API documentation
gem "rswag", "~> 2.17"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", "~> 1.0", platforms: %i[ mingw mswin x64_mingw jruby ]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache", "~> 1.0"
gem "solid_queue", "~> 1.7"
gem "solid_cable", "~> 4.1"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", "~> 1.26", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", "~> 2.12", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", "~> 0.1.27", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
# gem "image_processing", "~> 1.2"

group :development, :test do
  gem "byebug", "~> 13.0"

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", "~> 8.1", require: false

  # Testing framework & tooling
  gem "rspec-rails", "~> 8.0"
  gem "rswag-specs", "~> 2.17"
  gem "vcr", "~> 6.4"
  gem "webmock", "~> 3.34"
  gem "simplecov", "~> 1.3", require: false

  # Linting & code quality
  gem "rubocop", "~> 1.92", require: false
  gem "rubocop-rails", "~> 2.38", require: false
  gem "rubocop-rails-omakase", "~> 1.1", require: false
  gem "fasterer", "~> 0.11.0", require: false
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console", "~> 4.3"
  gem "annotate", github: "andynu/annotate_models", branch: "rails-8-0"
end
