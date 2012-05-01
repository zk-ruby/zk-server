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

      def initialize(opts={})
        @base_dir = Dir.getwd
        @zoo_cfg_hash = {}
        @tick_time = 2000
        @client_port = 2181
        @snap_count = nil
        @force_sync = nil
        @max_client_cnxns = 100


        opts.each { |k,v| __send__(:"#{k}=", v) }
      end

      def zoo_cfg_path
        File.join(base_dir, 'zoo.cfg')
      end

      def log4j_props_path
        File.join(base_dir, 'log4j.properties')
      end

      def data_dir
        File.join(base_dir, 'data')
      end

      def run
        create_files!
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
maxClientCnxns=#{maxClientCnxns}
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
