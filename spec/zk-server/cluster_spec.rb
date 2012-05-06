require 'spec_helper'

describe ZK::Server::Cluster do
  let(:tmpdir) { '/tmp/zookeeper' }

  let(:num_members) { 5 }

  subject do 
    described_class.new(num_members, :base_dir => tmpdir)
  end

  after do 
    subject.shutdown
#     subject.clobber!
#     FileUtils.rm_rf(tmpdir)
  end

  it %[should spawn a ZK server, ping, and then shutdown properly] do
    pending "cannot run this under JRuby" if defined?(::JRUBY_VERSION)

    subject.run

    wait_until { subject.all_running? }

    subject.should be_ping_all
    subject.should be_running

    subject.shutdown

    subject.should_not be_ping_all
    subject.should_not be_running
  end
end

