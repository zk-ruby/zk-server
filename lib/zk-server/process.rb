module ZK
  module Server
    # This encapsulates the logic of running the zookeeper server, as a sub-process.
    # It is intended that it will be stopped and started with the process that starts it.
    # We are not going to do daemonized process management. 
    #
    # By default, we will create a directory in the current working directory called 'zk'
    # to store our data under (configurable). 
    #
    class Process
      include FileUtils::Verbose

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
      # basis for all other path generation. Defaults to `File.join(Dir.getwd, 'zk-server')`
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
        @base_dir = File.join(Dir.getwd, 'zk-server')
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

      def data_dir
        File.join(base_dir, 'data')
      end

      def run
        create_files!
        puts command_args
      end

      def classpath
        @classpath ||= [Server.zk_jar_path, Server.log4j_jar_path, base_dir]
      end

      def command_args
        cmd = [Server.java_binary_path]
        cmd += %W[-Dzookeeper.log_dir=#{log_dir} -Dzookeeper.root.logger=INFO,CONSOLE]
        if enable_jmx
          cmd += DEFAULT_JMX_ARGS
          cmd << "-Dcom.sun.management.jmxremote.port=#{jmx_port}"
        end
        cmd += jvm_flags
        cmd += %W[-cp #{classpath.join(':')} #{ZOO_MAIN} #{zoo_cfg_path}]
      end

      protected
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
