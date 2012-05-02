require 'java'

# ok, this is a crime, i know

require 'zookeeper_jar'

module ZK
  module Server
    # gah, this needs to be a singleton, but whaddyagonnado
    class JavaEmbedded < Server
      # yeah, holla at ya boy, JZ
      module JZ
        Quorum          = org.apache.zookeeper.server.quorum
        Server          = org.apache.zookeeper.server
        FileTxnSnapLog  = org.apache.zookeeper.server.persistence.FileTxnSnapLog
      end

      JFile = java.io.File

      def shutdown
        @mutex.synchronize do
          return unless @run_called and @cnxn_factory and @zk_server and running?

          @cnxn_factory.shutdown
          @zk_server.shutdown
        end
      end

      def running?
        @mutex.synchronize do
          @zk_server && @zk_server.running?
        end
      end

      def run
        @mutex.synchronize do
          return false if @run_called
          @run_called = true

          create_files!
          spawn_zookeeper_thread!
          wait_until_ping
          true
        end
      end

      def spawned?
        !!@zookeeper_thread
      end

      def initialize_and_run
        main = JZ::Server::ZooKeeperServerMain.new
        main.run_from_config(config)
      end

      def pid
        $$ # CHEEKY!!
      end

      protected

        def spawn_zookeeper_thread!
          @zookeeper_thread ||= Thread.new do
            cnxn_factory.join
            cnxn_factory.shutdown

            @mutex.synchronize do
              @exit_cond.broadcast
            end
          end
        end

        def startup
          cnxn_factory.startup(zk_server)
        end

        def cnxn_factory
          @cnxn_factory ||= JZ::Server::NIOServerCnxn::Factory.new(zk_config.client_for_address, zk_config.max_client_cnxns)
        end

        def zk_server
          @zk_server ||= JZ::Server::ZooKeeperServer.new.tap do |zks|
            zks.txn_log_factory     = FileTxnSnapLog.new(JFile.new(zk_config.data_log_dir), JFile.new(zk_confg.data_dir))
            zks.tick_time           = zk_config.tick_time
            zks.min_session_timeout = config.min_session_timeout
            zks.max_session_timeout = config.max_session_timeout
          end
        end

        def zk_config
          @zk_config ||= JZ::Server::ServerConfig.new.tap { |c| c.parse(zoo_cfg_path) }
        end

    end
  end
end
