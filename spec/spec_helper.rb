require 'rubygems'
require 'bundler/setup'

Bundler.require(:default, :development, :test)

require 'zk-server'

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[File.expand_path("../{support,shared}/**/*.rb", __FILE__)].sort.each {|f| require f}

ZK::Server.logger = Logger.new($stderr).tap { |l| l.level = Logger::DEBUG }

RSpec.configure do |config|
  config.mock_with :rspec
  config.include(WaitWatchers)
  config.extend(WaitWatchers)
end

