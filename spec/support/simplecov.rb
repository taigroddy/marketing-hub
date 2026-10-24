require 'simplecov'

SimpleCov.start 'rails' do
  enable_coverage :branch

  # Enforce minimum 80% coverage on full suite runs
  is_partial_run = ARGV.any? { |arg| arg.include?('spec/') || arg.end_with?('_spec.rb') }
  minimum_coverage line: 80, branch: 80 unless is_partial_run

  skip '/bin/'
  skip '/db/'
  skip '/spec/'
  skip '/config/'

  group 'Clients', 'app/clients'
  group 'Services', 'app/services'
  group 'Contracts', 'app/contracts'
  group 'Blueprints', 'app/blueprints'
  group 'Controllers', 'app/controllers'
  group 'Models', 'app/models'
  group 'Jobs', 'app/jobs'
end
