require 'spec_helper'

describe ZK::Server::Process do
  let(:tmpdir) { '/tmp/zookeeper' }

  subject do 
    described_class.new(:client_port => 21812, :base_dir => tmpdir)
  end

  after do 
    subject.shutdown
    subject.clobber!
    FileUtils.rm_rf(tmpdir)
  end

  it %[should spawn a ZK server, ping, and then shutdown properly] do
#     pending "cannot run this under JRuby" if defined?(::JRUBY_VERSION)

    subject.run
    subject.should be_pingable
    subject.should be_running
    subject.should be_spawned
    subject.pid.should_not be_nil

    subject.shutdown

    subject.should_not be_pingable
    subject.should_not be_running
  end
end

