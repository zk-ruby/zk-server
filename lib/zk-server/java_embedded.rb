require 'java'

module ZK
  module Server
    # gah, this needs to be a singleton, but whaddyagonnado
    class JavaEmbedded < Base
      System = java.lang.System

      JFile = java.io.File

      attr_reader :zookeeper_thread
      
      # yeah, holla atcha boy, JZ
      module JZ
        # ok, this is seriously seriously ugly, but we want to dynamically
        # config log4j in this process which would require brain surgery if 
        # i didn't do it dynamically, therefore we need to have all of this stuff
        # bind late, and we want some readable shortcuts to these fully-qualified
        # path names *after* we've done our requires in 'require_dependencies'
        #
        # so, yeah, sorry about this

        def self.dynamically_create_consts
          hash = { 
            :Quorum         => org.apache.zookeeper.server.quorum,
            :Server         => org.apache.zookeeper.server,
            :FileTxnSnapLog => org.apache.zookeeper.server.persistence.FileTxnSnapLog 
          }
          
          hash.each do |k,v|
            $stderr.puts "dynamically creating constant #{name}::#{v}"
            const_set(k, v) unless const_defined?(k)
          end
        end
      end

      def shutdown
        @mutex.synchronize do
          return unless @run_called and @cnxn_factory and @zk_server and running?

          @cnxn_factory.shutdown
          @zk_server.shutdown
        end

        @zookeeper_thread and @zookeeper_thread.join(5)
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
          require_dependencies
          spawn_zookeeper_thread!
          wait_until_ping
          true
        end
      end

      def spawned?
        !!@zookeeper_thread
      end

      def pid
        $$ # CHEEKY!!
      end

      def logging_related_system_properties
        [ ['log4j.configuration', "file://#{ZK::Server.default_log4j_props_path}"],
          ['zookeeper.log.dir', config.log_dir],
          ['zookeeper.root.logger', 'INFO,CONSOLE'], ]
      end

      # XXX: this assumes that we're only going to ever run one of these per
      #      process (or at least have only one log)
      def require_dependencies
        logging_related_system_properties.each do |k,v|
          System.set_property(k,v)
        end

        require 'log4j'
        require 'zookeeper_jar'

        JZ.dynamically_create_consts
      end
      

      def spawn_zookeeper_thread!
        @zookeeper_thread ||= Thread.new do
          Thread.abort_on_exception = true
          cnxn_factory.startup(zk_server)
          cnxn_factory.join
          cnxn_factory.shutdown

          @mutex.synchronize do
            @exit_cond.broadcast
          end
        end
      end

      def cnxn_factory
        @cnxn_factory ||= JZ::Server::NIOServerCnxn::Factory.new(zk_config.client_port_address, zk_config.max_client_cnxns)
      end

      def j_data_log_dir
        @j_data_log_dir ||= JFile.new(zk_config.data_log_dir)
      end

      def j_data_dir
        @j_data_dir ||= JFile.new(zk_config.data_dir)
      end

      def zk_server
        @zk_server ||= JZ::Server::ZooKeeperServer.new(j_data_log_dir, j_data_dir, zk_config.tick_time)
      end

      def zk_config
        @zk_config ||= JZ::Server::ServerConfig.new.tap { |c| c.parse(zoo_cfg_path) }
      end
    end
  end
end
