require 'fileutils'
require 'forwardable'
require 'logger'
require 'socket'

# Yes, i know, this is arguably bad form, but i'm actually going to use bundler
# as an API

require 'rubygems'
require 'bundler'
require 'bundler/setup'

require 'slop'

# require 'zk'

#ZK.logger = Logger.new($stderr).tap { |l| l.level = Logger::DEBUG }

module ZK
  module Server

    ZK_JAR_GEM  = 'slyphon-zookeeper_jar'
    LOG4J_GEM   = 'slyphon-log4j'

    def self.mri_187?
      ruby_187? and not rubinius? and not jruby?
    end

    def self.ruby_19?
      false|(RUBY_VERSION =~ /\A1\.9/)
    end

    def self.ruby_187?
      RUBY_VERSION == '1.8.7'
    end

    def self.jruby?
      defined?(::JRUBY_VERSION)
    end

    def self.jruby_18?
      jruby? and ruby_187?
    end

    def self.jruby_19?
      jruby? and ruby_19?
    end

    def self.rubinius?
      defined?(::Rubinius)
    end

    # Create a new {ZK::Server::Process} instance. if a block is given
    # then yield the {Config} object to the block
    #
    # @yield [Config] server config instance if block given
    def self.new(opts={})
      klass = jruby? ? JavaEmbedded : SubProcess

      klass.new(opts).tap do |server|
        yield server.config if block_given?
      end
    end

    # runs a server as a singleton instance. use ZK::Server.shutdown to stop and ZK::Server.clear
    # to reset
    def self.run(opts={}, &blk)
      @server ||= new(opts, &blk).tap { |s| s.run }
    end

    # a singleton server instance (if start was called)
    def self.server
      @server
    end
    
    def self.shutdown
      @server and @server.shutdown
    end

    def self.clear
      @server = nil if @server and not @server.running?
    end

    def self.zk_jar_path
      # in future revisions of the zookeeper jar, we'll make it easier to get
      # at this information without needing rubygems and bundler to get at it,
      # but for now this is the best way

      @zk_jar_path ||= get_jar_paths_from_gem(ZK_JAR_GEM).first
    end

    def self.log4j_jar_path
      @log4j_jar_path ||= get_jar_paths_from_gem(LOG4J_GEM).first
    end

    def self.get_jar_paths_from_gem(gem_name)
      glob = "#{get_spec_for(gem_name).lib_dirs_glob}/**/*.jar"

      Dir[glob].tap do |ary|
        raise "gem #{gem_name} did not contain any jars (using glob: #{glob.inspect})" if ary.empty?
      end
    end

    def self.get_spec_for(gem_name)
      not_found = proc do
        raise "could not locate the #{gem_name} Gem::Specification! wtf?!"
      end

      Bundler.load.specs.find(not_found) { |s| s.name == gem_name }
    end

    def self.java_binary_path=(path)
      @java_binary_path = path
    end

    def self.java_binary_path
      @java_binary_path ||= which('java')
    end

    def self.which(bin_name)
      if_none = proc { "Could not find #{bin_name} in PATH: #{ENV['PATH'].inspect}" }
      ENV['PATH'].split(':').map{|n| File.join(n, bin_name) }.find(if_none) {|x| File.executable?(x) }
    end

    def self.default_log4j_props_path
      File.expand_path('../zk-server/log4j.properties', __FILE__)
    end
  end
end

require 'zk-server/version'
require 'zk-server/logging'
require 'zk-server/config'
require 'zk-server/base'
require 'zk-server/sub_process'
require 'zk-server/cluster'
require 'zk-server/command'

if defined?(::JRUBY_VERSION)
  require 'zk-server/java_embedded'
end

