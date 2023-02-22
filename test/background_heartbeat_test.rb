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
          assert_equal base_thread_count + 1, Thread.list.length
        end
        assert_equal base_thread_count, Thread.list.length
      end

      describe 'with a long interval' do
        let(:subject) { BackgroundHeartbeat.new(queue_audit, 100) }

        it 'aborts if requested to' do
          t1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          subject.with_heartbeat do
            sleep 1
          end
          t2 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          # The important thing is that this takes 1 second, not 100 seconds, so use a big delta.
          assert_in_delta (t2 - t1), 1, 10
        end
      end
    end
  end
end
