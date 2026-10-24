require 'vcr'
require 'webmock/rspec'

VCR.configure do |config|
  config.cassette_library_dir = 'spec/fixtures/vcr_cassettes'
  config.hook_into :webmock
  config.configure_rspec_metadata!

  config.ignore_localhost = true
  config.ignore_hosts '127.0.0.1', 'localhost', 'db', 'redis', 'mailpit'
end

WebMock.disable_net_connect!(
  allow_localhost: true,
  allow: [ '127.0.0.1', 'localhost', 'db', 'redis', 'mailpit' ]
)
