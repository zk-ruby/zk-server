require 'thread'

module ZK
  module Server
    class Command 
      include Logging

      def initialize
        @mutex  = Mutex.new
        @cond   = ConditionVariable.new
        @shutdown_requested = false
      end

      def spawn_shutdown_handler
        @shutdown_thread ||= Thread.new do
          @mutex.synchronize do
            @cond.wait until @shutdown_requested
            logger.debug { "shutdown thread awakened! shutting down server!" }
            @server.shutdown if @server
          end
        end
      end

      def run
        opts = Slop.parse(:help => true, :strict => true) do
          banner "zk-server [opts] runs a ZooKeeper server in the foreground"
          on :d,  :base_dir=,   "defaults to #{ZK::Server::Config.default_base_dir}" 
          on      :force_sync,  'force fsync on every snapshot'
          on      :skip_acl,    'skip acl checks'
          on :p,  :port=,       'port to listen on', :as => :integer
          on      :jvm_flags=,  'additional JVM flags to pass'
          on      :snap_count=, 'how often to take a snapshot, default 100_000', :as => :integer
        end

        return if opts.help?

        hash = opts.to_hash

        hash.delete(:help)
        hash.reject! { |k,v| v.nil? }

        config = ZK::Server::Config.new(hash)

        spawn_shutdown_handler


        %w[HUP INT].each do |sig|
          trap(sig) do
            @mutex.synchronize do
              $stderr.puts "trapped #{sig}, shutting down"
              @shutdown_requested = true
              @cond.broadcast
            end
          end
        end

        @server = ZK::Server.new(:config => config)
        @server.run

        unless @server.join
          $stderr.puts "server exited with status #{@server.status.inspect}"
          st = @server.status
          exit st.exited? ? st.exitstatus : 42
        end
      end
    end
  end
end

