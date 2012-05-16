module ZK
  module Server
    # common base class for Process and JavaEmbedded classes
    class Base
      extend Forwardable
      include FileUtils
      include Logging

      def_delegators :config,
        :base_dir, :data_dir, :log4j_props_path, :command_args,
        :client_port, :stdio_redirect_path, :zoo_cfg_path,
        :zoo_myid_path, :myid

      # the {Config} object that will be used to configure this Process
      attr_accessor :config

      def initialize(opts={})
        @child_startup_timeout = opts.delete(:child_startup_timeout) || 6

        @run_called = false
        @config     = opts[:config] || Config.new(opts)

        @mutex      = Monitor.new
        @exit_cond  = @mutex.new_cond
      end

      # removes all files related to this instance
      # runs {#shutdown} first
      def clobber!
        shutdown
        FileUtils.rm_rf(base_dir)
      end

      # is the server running?
      def running?
        raise NotImplementedError
      end

      # shut down the server, gracefully if possible, with force if necessary
      def shutdown
        raise NotImplementedError
      end

      # can we connect to the server, issue an 'ruok', and receive an 'imok'?
      def ping?
        TCPSocket.open('localhost', client_port) do |sock|
          sock.puts('ruok')
          sock.read == 'imok'
        end
      rescue
        false
      end
      alias pingable? ping?

      # start the server
      def run
        raise NotImplementedError
      end

      protected
        def wait_until_ping(timeout=5)
          times_up = timeout ? Time.now + timeout : 0
          while Time.now < times_up
            return true if ping?
          end
          false
        end

        def create_files!
          mkdir_p base_dir
          mkdir_p data_dir
          write_myid!
          write_zoo_cfg!
          write_log4j_properties!
          mkdir_p(File.dirname(stdio_redirect_path))
        end

        def write_log4j_properties!
          unless File.exists?(log4j_props_path)
            cp ZK::Server.default_log4j_props_path, log4j_props_path
          end
        end

        def write_myid!
          File.open(zoo_myid_path, 'w') do |io|
            io.puts myid
          end
        end

        def write_zoo_cfg!
          File.open(zoo_cfg_path, 'w') do |fp|
            fp.puts(config.to_config_file_str)
            fp.fsync
          end
        end
    end
  end
end


