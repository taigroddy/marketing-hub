require 'vcr'
require 'webmock/rspec'

VCR.configure do |config|
  config.cassette_library_dir = 'spec/fixtures/vcr_cassettes'
  config.hook_into :webmock
  config.configure_rspec_metadata!

  config.ignore_localhost = true
  config.ignore_hosts '127.0.0.1', 'localhost', 'db', 'redis', 'mailpit'

  config.filter_sensitive_data('<FB_APP_ID>') { ENV['FB_APP_ID'] }
  config.filter_sensitive_data('<FB_APP_SECRET>') { ENV['FB_APP_SECRET'] }
  if ENV['FB_TEST_ACCESS_TOKEN'].present?
    config.filter_sensitive_data('<FB_TEST_ACCESS_TOKEN>') { ENV['FB_TEST_ACCESS_TOKEN'] }
    config.filter_sensitive_data('<FB_TEST_ACCESS_TOKEN>') { CGI.escape(ENV['FB_TEST_ACCESS_TOKEN']) }
  end

  config.default_cassette_options = {
    record: :once,
    match_requests_on: %i[method uri body]
  }
end

WebMock.disable_net_connect!(
  allow_localhost: true,
  allow: [ '127.0.0.1', 'localhost', 'db', 'redis', 'mailpit' ]
)
