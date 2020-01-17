require_relative './test_helper'

module Resque::Durable
  describe BackgroundHeartbeat do
    let(:subject) { BackgroundHeartbeat.new(queue_audit, 0.01) }
    let(:queue_audit) { QueueAudit.initialize_by_klass_and_args(MailQueueJob, [ 'hello' ]) }

    before do
      queue_audit.save!
    end

    describe '#with_heartbeat' do
      it 'heartbeats in the background for the requested interval' do
        # Thread timing is not deterministic. Using a 2x margin of variation.
        # Locally, this averaged 88 with a stddev of 1.4
        queue_audit.expects(:optimistic_heartbeat!).times((50..150))
        subject.with_heartbeat do
          sleep 1
        end
      end

      it 'aborts if another thread heartbeats' do
        BackgroundHeartbeat.expects(:exit_now!).at_least_once
        subject.with_heartbeat do
          queue_audit.heartbeat!
          sleep 0.1
        end
      end

      it 'starts a thread and shuts it down before returning' do
        base_thread_count = Thread.list.length
        subject.with_heartbeat do
          Thread.list.length.must_equal base_thread_count + 1
        end
        Thread.list.length.must_equal base_thread_count
      end
    end
  end
end
