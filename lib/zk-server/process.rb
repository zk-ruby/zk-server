module ZK
  module Server
    # This encapsulates the logic of running the zookeeper server, as a sub-process.
    # It is intended that it will be stopped and started with the process that starts it.
    # We are not going to do daemonized process management. 
    #
    # By default, we will create a directory in the current working directory called 'zk-server'
    # to store our data under (configurable). 
    #
    class Process
      include ZK::Logging
      extend Forwardable
      include FileUtils::Verbose

      def_delegators :config,
        :base_dir, :data_dir, :log4j_props_path, :log_dir, :command_args,
        :tick_time, :snap_count, :force_sync, :zoo_cfg_hash, :client_port,
        :max_client_cnxns, :stdio_redirect_path, :zoo_cfg_path

      # the {Config} object that will be used to configure this Process
      attr_accessor :config

      attr_reader :exit_status

      # how long should we wait for the child to start responding to 'ruok'?
      attr_accessor :child_startup_timeout

      def initialize(opts={})
        @child_startup_timeout = opts.delete(:child_startup_timeout, 5)
        @run_called = false
        @config = Config.new(opts)
        @exit_watching_thread = nil

        @pid = nil
        @exit_status = nil

        @mutex      = Monitor.new
        @exit_cond  = @mutex.new_cond
      end

      # removes all files related to this instance
      # runs {#shutdown} first
      def clobber!
        shutdown
        FileUtils.rm_rf(base_dir)
      end

      # true if the process was started and is still running
      def running?
        spawned? and !@exit_status and !!::Process.kill(0, @pid)
      rescue Errno::ESRCH
        false
      end

      # have we started the child process?
      def spawned?
        !!@pid
      end

      # shutdown the child, wait for it to exit, ensure it is dead
      def shutdown
        if @pid
          return if @exit_status

          @mutex.synchronize do
            %w[HUP TERM KILL].each do |signal|
              logger.debug { "sending #{signal} to #{@pid}" }

              begin
                ::Process.kill(signal, @pid)
              rescue Errno::ESRCH
                break
              end

              if @exit_status or @exit_cond.wait(5)
                logger.debug { "process exited" }
                break
              end
            end
          end

          logger.debug { "@exit_status: #{@exit_status}" }
        end
        true
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

      # the pid of our child process
      def pid
        @pid
      end

      # start the child, using the {#config}. we create the files necessary,
      # fork the child, and wait 5s for the child to start responding to pings
      #
      #
      # @return [false,true] false if run has already been called on this instance
      #   true if we hav
      def run
        return false if @run_called
        @run_called = true

        create_files!
        fork_and_exec!
        spawn_exit_watching_thread

        unless wait_until_ping
          raise "Oh noes! something went wrong!" unless running?
        end

        at_exit { self.shutdown }

        true
      end

      protected
        def wait_until_ping(timeout=5)
          times_up = timeout ? Time.now + timeout : 0
          while Time.now < times_up
            return true if ping?
          end
          false
        end

        def spawn_exit_watching_thread
          @exit_watching_thread ||= Thread.new do
            _, @exit_status = ::Process.wait2(@pid)
            @mutex.synchronize do
              @exit_cond.broadcast
            end
          end
        end

        # wait for up to timeout seconds to pass, polling for completion
        # returns nil if the process didn't exit
        def wait_for_pid(timeout=2)
          times_up = timeout ? Time.now + timeout : 0

          while Time.now < times_up
            pid, stat = ::Process.wait2(@pid, ::Process::WNOHANG)
            return stat if stat
            sleep(0.01)
          end

          nil
        end

        def fork_and_exec!
          @pid ||= (
            args = command_args()
            args << {:err => [:child, :out], :out => [stdio_redirect_path, File::APPEND|File::CREAT|File::WRONLY]}
            spawn({}, *command_args)
          )
        end

        def create_files!
          mkdir_p base_dir
          mkdir_p data_dir
          write_zoo_cfg!
          write_log4j_properties!
        end

        def write_log4j_properties!
          unless File.exists?(log4j_props_path)
            cp Server.default_log4j_props_path, log4j_props_path
          end
        end

        def write_zoo_cfg!
          File.open(zoo_cfg_path, 'w') do |fp|
            fp.puts <<-EOS
tickTime=#{tick_time}
dataDir=#{data_dir}
clientPort=#{client_port}
maxClientCnxns=#{max_client_cnxns}
            EOS

            fp.puts("forceSync=#{force_sync}") if force_sync
            fp.puts("snapCount=#{snap_count}") if snap_count
            zoo_cfg_hash.each do |k,v|
              fp.puts("#{k}=#{v}")
            end

            fp.fsync
          end
        end
    end
  end
end
