module ZK
  module Server
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

      # default: no value set
      attr_accessor :snap_count

      # default: no value set
      attr_accessor :force_sync

      # if truthy, will enable jmx (defaults to false)
      # note that our defualt jmx config has all security and auth turned off
      # if you want to customize this, then use jvm_flags and set this to false
      attr_accessor :enable_jmx

      # default jmx port is 22222
      attr_accessor :jmx_port

      # array to which additional JVM flags should be added
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

        @max_client_cnxns = 100

        opts.each { |k,v| __send__(:"#{k}=", v) }
      end

      def zoo_cfg_path
        File.join(base_dir, 'zoo.cfg')
      end

      def log4j_props_path
        File.join(base_dir, 'log4j.properties')
      end

      def log_dir
        File.join(base_dir, 'log')
      end

      def stdio_redirect_path
        File.join(log_dir, 'zookeeper.out')
      end

      def data_dir
        File.join(base_dir, 'data')
      end

      def classpath
        @classpath ||= [Server.zk_jar_path, Server.log4j_jar_path, base_dir]
      end

      def command_args
        cmd = [Server.java_binary_path]
        cmd += %W[-Dzookeeper.log.dir=#{log_dir} -Dzookeeper.root.logger=INFO,CONSOLE]
        if enable_jmx
          cmd += DEFAULT_JMX_ARGS
          cmd << "-Dcom.sun.management.jmxremote.port=#{jmx_port}"
        end
        cmd += jvm_flags
        cmd += %W[-cp #{classpath.join(':')} #{ZOO_MAIN} #{zoo_cfg_path}]
      end
    end
  end
end

