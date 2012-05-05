module ZK
  module Server
    # Note that this supports all of the 3.3.5 options, but __will not__ do any
    # sanity checking for you. All options specifyable here (especially those that
    # require directories to be created outside of {#base_dir}) may not be handled
    # properly by {Base} and subclasses.
    #
    class Config
      DEFAULT_JVM_FLAGS = %w[
        -server
        -Xmx256m
        -Dzookeeper.serverCnxnFactory=org.apache.zookeeper.server.NettyServerCnxnFactory
      ].freeze

      # the com.sun.managemnt.jmxremote.port arg will be filled in dynamically
      # based on the {#jmx_port} value
      #
      DEFAULT_JMX_ARGS = %w[
        -Dcom.sun.management.jmxremote=true
        -Dcom.sun.management.jmxremote.local.only=false
        -Dcom.sun.management.jmxremote.authenticate=false
        -Dcom.sun.management.jmxremote.ssl=false
      ].freeze

      ZOO_MAIN = 'org.apache.zookeeper.server.quorum.QuorumPeerMain'.freeze

      # The top level directory we will store all of our data under. used as the
      # basis for all other path generation. Defaults to `File.join(Dir.getwd, 'zookeeper')`
      attr_accessor :base_dir

      # defaults to `#{base_dir}/data`. use this to override the default
      #
      # > the location where ZooKeeper will store the in-memory database
      # > snapshots and, unless specified otherwise, the transaction log of
      # > updates to the database.
      #
      # be aware that the {ZK::Server::Base} class will not create any
      # directories but {#base_dir}.
      #
      attr_writer :data_dir

      # defaults to nil, and zookeeper will just use the default value (being the
      # same as {#data_dir}
      #
      # > This option will direct the machine to write the transaction log to the
      # > dataLogDir rather than the dataDir. This allows a dedicated log device
      # > to be used, and helps avoid competition between logging and snaphots.
      #
      attr_accessor :data_log_dir

      # a hash that will be used to provide extra values for the zoo.cfg file.
      # keys are written as-is to the file, so they should be camel-cased.
      #
      # dataDir will be set relative to {#base_dir} and clientPort will either use
      # the default of 2181, or can be adjusted by {#client_port=}
      #
      attr_accessor :zoo_cfg_hash

      # what port should the server listen on for connections? (default 2181)
      attr_accessor :client_port
      alias port client_port
      alias port= client_port=

      # maximum number of client connections (defaults to 100)
      attr_accessor :max_client_cnxns

      # defaults to 2000
      attr_accessor :tick_time

      # what cluster id should this zookeeper use for itself? (default 1)
      attr_accessor :myid

      # default is nil, and will not be specified in the config
      #
      # > Clients can submit requests faster than ZooKeeper can process them,
      # > especially if there are a lot of clients. To prevent ZooKeeper from
      # > running out of memory due to queued requests, ZooKeeper will throttle
      # > clients so that there is no more than globalOutstandingLimit
      # > outstanding requests in the system. The default limit is 1,000.
      #
      attr_accessor :global_outstanding_limit

      # necessary for cluster nodes (default 5)
      #
      # from the zookeeper admin guide:
      # > Amount of time, in ticks (see tickTime), to allow followers to connect
      # > and sync to a leader. Increased this value as needed, if the amount of data
      # > managed by ZooKeeper is large.
      #
      attr_accessor :init_limit

      # necessary for cluster nodes (default 2)
      #
      # > Amount of time, in ticks (see tickTime), to allow followers to sync
      # > with ZooKeeper. If followers fall too far behind a leader, they will be
      # > dropped.
      #
      attr_accessor :sync_limit

      # from the [admin guide](http://zookeeper.apache.org/doc/r3.3.5/zookeeperAdmin.html)
      #
      # > ZooKeeper logs transactions to a transaction log. After snapCount
      # > transactions are written to a log file a snapshot is started and a new
      # > transaction log file is created. The default snapCount is 100,000.
      #
      # For testing, to speed up disk IO, I generally set this to 1_000_000 and
      # force_sync to false. YMMV, understand what this does before messing with it
      # if you care about your data.
      #
      # default: unset
      attr_accessor :snap_count

      # This value can make testing go faster, as zookeeper doesn't have to issue
      # an fsync() call for each snapshot write. It is however DANGEROUS if you
      # care about the data. (I set it to false for running tests)
      #
      # if true: 'yes', false: 'no', nil not specified in the config
      #
      # default: no value set
      attr_accessor :force_sync

      # default: nil
      #
      # > To avoid seeks ZooKeeper allocates space in the transaction log file in
      # > blocks of preAllocSize kilobytes. The default block size is 64M. One
      # > reason for changing the size of the blocks is to reduce the block size
      # > if snapshots are taken more often. (Also, see snapCount).
      attr_accessor :pre_alloc_size

      # default: nil
      #
      # > the address (ipv4, ipv6 or hostname) to listen for client
      # > connections; that is, the address that clients attempt to connect to.
      # > This is optional, by default we bind in such a way that any connection
      # > to the clientPort for any address/interface/nic on the server will be
      # > accepted.
      #
      attr_accessor :client_port_address

      # default: nil
      #
      # > the minimum session timeout in milliseconds that the server will allow
      # > the client to negotiate. Defaults to 2 times the tickTime
      #
      attr_accessor :min_session_timeout

      # default: nil
      #
      # > the maximum session timeout in milliseconds that the server will allow
      # > the client to negotiate. Defaults to 20 times the tickTime.
      attr_accessor :max_session_timeout

      # default: nil
      #
      # If true, the value 'yes' will be used for this value, false will write 'no'
      # to the config file. The default (nil) is not to specify a value in the config.
      #
      # > Leader accepts client connections. Default value is "yes". The leader
      # > machine coordinates updates. For higher update throughput at thes
      # > slight expense of read throughput the leader can be configured to not
      # > accept clients and focus on coordination. The default to this option is
      # > yes, which means that a leader will accept client connections
      #
      attr_accessor :leader_serves

      # default: nil 
      #
      # by default this is not specified
      #
      # > Sets the timeout value for opening connections for leader election
      # > notifications.
      #
      attr_accessor :cnx_timeout

      # default: nil
      #
      # if true: 'yes', false: 'no', nil not specified in the config
      #
      # this is listed as a DANGEROUS setting
      #
      # > Skips ACL checks. This results in a boost in throughput, but opens up
      # > full access to the data tree to everyone.
      attr_accessor :skip_acl

      # if truthy, will enable jmx (defaults to false)
      # note that our defualt jmx config has all security and auth turned off
      # if you want to customize this, then use jvm_flags and set this to false
      attr_accessor :enable_jmx

      # default jmx port is 22222
      attr_accessor :jmx_port

      # array to which additional JVM flags should be added
      #
      # default is {DEEFAULT_JVM_FLAGS}
      attr_accessor :jvm_flags


      def initialize(opts={})
        @base_dir = File.join(Dir.getwd, 'zookeeper')
        @zoo_cfg_hash = {}
        @tick_time    = 2000
        @client_port  = 2181
        @snap_count   = nil
        @force_sync   = nil
        @jmx_port     = 22222
        @enable_jmx   = false
        @jvm_flags    = DEFAULT_JVM_FLAGS.dup
        @myid         = 1
        @init_limit   = 5
        @sync_limit   = 2

        @max_client_cnxns = 100

        opts.each { |k,v| __send__(:"#{k}=", v) }
      end

      # @private
      def zoo_cfg_path
        File.join(base_dir, 'zoo.cfg')
      end

      # @private
      def zoo_myid_path
        File.join(base_dir, 'data', 'myid')
      end

      # @private
      def log4j_props_path
        File.join(base_dir, 'log4j.properties')
      end

      # @private
      def log_dir
        File.join(base_dir, 'log')
      end

      # @private
      def stdio_redirect_path
        File.join(log_dir, 'zookeeper.out')
      end

      # @private
      def data_dir
        @data_dir ||= File.join(base_dir, 'data')
      end

      # @private
      def classpath
        @classpath ||= [ZK::Server.zk_jar_path, ZK::Server.log4j_jar_path, base_dir]
      end

      # @private
      def command_args
        cmd = [ZK::Server.java_binary_path]
        cmd += %W[-Dzookeeper.log.dir=#{log_dir} -Dzookeeper.root.logger=INFO,CONSOLE]
        if enable_jmx
          cmd += DEFAULT_JMX_ARGS
          cmd << "-Dcom.sun.management.jmxremote.port=#{jmx_port}"
        end
        cmd += jvm_flags
        cmd += %W[-cp #{classpath.join(':')} #{ZOO_MAIN} #{zoo_cfg_path}]
      end

      # renders this config as a string that can be written to zoo.cfg
      def to_config_file_str
        config = {
          'dataDir'                 => data_dir,
          'skipACL'                 => skip_acl,
          'tickTime'                => tick_time,
          'initLimit'               => init_limit,
          'syncLimit'               => sync_limit,
          'forceSync'               => force_sync,
          'snapCount'               => snap_count,
          'clientPort'              => client_port,
          'dataLogDir'              => data_log_dir,
          'preAllocSize'            => pre_alloc_size,
          'leaderServes'            => leader_serves,
          'maxClientCnxns'          => max_client_cnxns,
          'clientPortAddress'       => client_port_address,
          'minSessionTimeout'       => min_session_timeout,
          'maxSessionTimeout'       => max_session_timeout,
          'globalOutstandingLimit'  => global_outstanding_limit,
        }
        
        config = config.merge(zoo_cfg_hash)

        config.delete_if { |k,v| v.nil? }

        %w[leaderServes skipACL forceSync].each do |yorn_key|
          if config.has_key?(yorn_key)
            config[yorn_key] = config[yorn_key] ? 'yes' : 'no'
          end
        end

        config.sort.map {|kv| kv.join("=") }.join("\n")
      end
    end
  end
end

