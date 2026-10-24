require 'simplecov'

SimpleCov.start 'rails' do
  enable_coverage :branch
  minimum_coverage line: 80, branch: 80

  skip '/bin/'
  skip '/db/'
  skip '/spec/'
  skip '/config/'

  group 'Services', 'app/services'
  group 'Contracts', 'app/contracts'
  group 'Blueprints', 'app/blueprints'
  group 'Controllers', 'app/controllers'
  group 'Models', 'app/models'
  group 'Jobs', 'app/jobs'
end
