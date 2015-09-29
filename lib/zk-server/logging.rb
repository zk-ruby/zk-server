module ZK
  module Server
    # default logger instance
    @logger ||= ::Logger.new($stderr).tap { |l| l.level = ::Logger::FATAL }

    class << self
      attr_accessor :logger
    end

    # we might not have ZK::Logging, so we define our own
    module Logging
      def self.included(mod)
        mod.extend(ZK::Server::Logging)
        super
      end

      def logger
        ZK::Server.logger
      end
    end
  end
end
