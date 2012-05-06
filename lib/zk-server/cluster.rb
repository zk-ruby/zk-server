module ZK
  module Server
    # Cluster simplifies the case when you want to test a 3+ node cluster
    # You give the base_dir, and number of nodes, and it will construct a
    # cluster for you. It's less configurable than the SubProcess class, but
    # that's the price of convenience! 
    class Cluster
      FOLLOWER_PORT_OFFSET  = 100
      LEADER_PORT_OFFSET    = 200
      DEFAULT_BASE_PORT     = 21811

      attr_accessor :base_dir

      # defaults to 21811, used as the lowest port number for the cluster,
      # all others will be offsets of this number
      attr_accessor :base_port

      # access to the SubProcess instances that make up this cluster
      attr_reader :processes

      # how many nodes in the cluster
      attr_reader :num_members

      def initialize(num_members, opts={})
        @num_members  = num_members
        @base_dir     = Config.default_base_dir
        @base_port    = DEFAULT_BASE_PORT
        @processes    = nil
        @running      = false
        opts.each { |k,v| __send__(:"#{k}=", v) }
      end

      def running?
        !!@running
      end

      def run
        return if running?
        @running = true

        processes.each { |p| p.run }
      rescue Exception
        processes.each { |p| p.shutdown }
        raise
      end

      def shutdown
        return unless running?
        @running = false

        pary, @processes = @processes, nil

        pary.each(&:shutdown)
        pary
      end

      def clobber!
        processes.each(&:clobber!)
      end

      def all_running?
        processes.all?(&:running?)
      end

      def ping_all?
        processes.all?(&:ping?)
      end

      def processes
        @processes ||= [].tap do |ary|
          num_members.times do |idx|
            ary << SubProcess.new.tap do |sp|
              c = sp.config

              c.myid          = idx
              c.base_dir      = File.join(@base_dir, "server-#{idx}")
              c.client_port   = base_port + idx
              c.zoo_cfg_hash  = server_hash
            end
          end
        end
      end

      # terrible name, the list of 'servers' lines in the config
      #
      def server_hash
        @server_hash ||= {}.tap do |h|
          num_members.times do |idx|
            h["server.#{idx}"] = "127.0.0.1:#{base_port + FOLLOWER_PORT_OFFSET + idx}:#{base_port + LEADER_PORT_OFFSET + idx}"
          end
        end
      end

    end # Cluster
  end # Server
end # ZK
