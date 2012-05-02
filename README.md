# ZK::Server

Sets up and runs a ZooKeeper standalone server process. Intended for use during testing of zookeeper-related code. The following are the design goals:

* Easy to configure and run
* Never ever leaks a process (barring impossible circumstances)


## Usage

Example usage:

```
server = ZK::Server.new do |config|
  config.client_port = 21811
  config.enable_jmx = true
  config.force_sync = false
end

server.run

# do a bunch of stuff (like run your specs)

server.shutdown
```

For full options, see [ZK::Server::Config](http://rubydoc.info/github/slyphon/zk-server/master/ZK/Server/Config)

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
