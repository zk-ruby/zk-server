module ZK
  module Server
    # This encapsulates the logic of running the zookeeper server, as a sub-process.
    # It is intended that it will be stopped and started with the process that starts it.
    # We are not going to do daemonized process management. 
    #
    # By default, we will create a directory in the current working directory called 'zk-server'
    # to store our data under (configurable). 
    #
    class SubProcess < Base
      attr_reader :status

      # how long should we wait for the child to start responding to 'ruok'?
      attr_accessor :child_startup_timeout

      def initialize(opts={})
        @exit_watching_thread = nil

        @pid = nil
        @status = nil

        super
      end

      # wait for sub-process to exit
      def join
        @mutex.synchronize do
          logger.debug { "spawned process #{@pid}" }
          @exit_cond.wait_until { @status }
        end
        @status.success?
      end
      
      # true if the process was started and is still running
      def running?
        spawned? and !@status and alive?
      end

      def alive?
        return false unless spawned?
        false|kill(0)
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
          return if @status

          @mutex.synchronize do
            %w[HUP TERM KILL].each do |signal|
              logger.debug { "sending #{signal} to #{@pid}" }

              return unless running? # jruby doesn't seem to get @status ?

              begin
                kill(signal)
              rescue Errno::ESRCH
                return true
              end

              @exit_cond.wait(5) # check running? on next pass
            end
          end

          unless @exit_watching_thread.join(3) == @exit_watching_thread
            logger.warn { "exit watching thread didn't exit after 3 sec" }
          end

          @pid = @exit_watching_thread = nil

          logger.debug { "@status: #{@status}" }
        end
        true
      end

      # the pid of our child process
      def pid
        @pid
      end

      def kill(signal)
        raise "No pid yet!" unless @pid
        Process.kill(signal, @pid)
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

        if ZK::Server.mri_187?
          fork_and_exec!
        elsif ZK::Server.jruby? and not ZK::Server.ruby_19?
          raise "You must run Jruby in 1.9 compatibility mode! I'm very sorry, i need Kernel.spawn"
        else
          spawn!
        end

        spawn_exit_watching_thread

        unless wait_until_ping(@child_startup_timeout)
          raise "Oh noes! something went wrong!" unless running?
        end

        at_exit { self.shutdown }

        true
      end

      protected
        def spawn_exit_watching_thread
          @exit_watching_thread ||= Thread.new do
            _, @status = Process.wait2(@pid)
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

        def spawn!
          @pid ||= (
            args = command_args()
            args << { :err => [:child, :out], :out => [stdio_redirect_path, 'w'] }
            ::Kernel.spawn({}, *command_args).tap do |pid|
              logger.debug { "Spawned process #{pid}" }
            end
          )
        end

        def fork_and_exec!
          @pid ||= 
            fork do                 # gah, use fork because 1.8.7 sucks
              3.upto(255) do |fd|
                begin
                  if io = IO.new(fd)
                    io.close
                  end
                rescue
                end
              end

              $stderr.puts "stdio_redirect_path: #{stdio_redirect_path.inspect}"
              $stdout.reopen($stderr)
              $stderr.reopen(stdio_redirect_path, 'a')

              exec(*command_args)
            end
        end

    end
  end
end
