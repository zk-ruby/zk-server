require 'spec_helper'

if defined?(::JRUBY_VERSION)

  describe ZK::Server::JavaEmbedded do
    let(:tmpdir) { '/tmp/zookeeper' }

    subject do 
      described_class.new(:client_port => 21812, :base_dir => tmpdir)
    end

    after do 
      subject.shutdown
      subject.clobber!
      FileUtils.rm_rf(tmpdir)
    end
 

    it %[should run the zk server, ping, and then shutdown properly] do
      subject.run
      subject.should be_pingable
      subject.should be_running
      subject.should be_spawned

      subject.shutdown

      subject.should_not be_pingable
      subject.should_not be_running
    end
  end
end

