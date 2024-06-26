require File.join(File.dirname(__FILE__), 'test_helper')

module Resque::Durable
  class DurableTest < Minitest::Test

    describe 'Durable queue' do
      before do
        QueueAudit.delete_all
        GUID.stubs(:generate).returns('abc/1/12345')
        Resque.expects(:enqueue).with(Resque::Durable::MailQueueJob, :foo, :bar, 'abc/1/12345')
        MailQueueJob.enqueue(:foo, :bar)
      end

      describe 'enqueue' do
        it 'creates an audit' do
          audit = QueueAudit.find_by_enqueued_id('abc/1/12345')

          assert_equal 'abc/1/12345', audit.enqueued_id
        end

      end

      describe 'enqueue failure' do
        before do
          QueueAudit.delete_all
          Resque.expects(:enqueue).raises(ArgumentError.new)
        end

        it 'raises an error by default' do
          assert_raises(ArgumentError) do
            MailQueueJob.enqueue(:ka, :boom)
          end
        end

        it 'has overridable exception handling' do
          class NewMailQueueJob < MailQueueJob
            def self.enqueue_failed(exception, args)
              @called = [exception.class, args]
            end
          end

          NewMailQueueJob.enqueue(:ka, :boom)
          assert_equal [ArgumentError, [:ka, :boom, "abc/1/12345"]], NewMailQueueJob.instance_variable_get(:@called)
        end

        it 'creates an audit' do
          assert_raises(ArgumentError) do
            MailQueueJob.enqueue(:ka, :boom)
          end
          audit = QueueAudit.find_by_enqueued_id('abc/1/12345')

          assert_equal 'abc/1/12345', audit.enqueued_id
        end

      end

      describe 'a missing audit' do

        it 'is reported with an exception' do
          audit = QueueAudit.find_by_enqueued_id('abc/1/12345')
          audit.destroy
          assert_raises(ArgumentError) do
            MailQueueJob.around_perform_manage_audit('hello', "foo", 'abc/1/12345') {}
          end
        end

      end

      describe 'around perform' do
        it 'completes the audit' do
          audit = QueueAudit.find_by_enqueued_id('abc/1/12345')
          assert !audit.complete?

          MailQueueJob.around_perform_manage_audit('hello', "foo", 'abc/1/12345') {}

          audit = QueueAudit.find_by_enqueued_id('abc/1/12345')
          assert audit.complete?
        end

        it 'should not complete on failure' do
          audit = QueueAudit.find_by_enqueued_id('abc/1/12345')
          assert !audit.complete?

          MailQueueJob.around_perform_manage_audit('hello', "foo", 'abc/1/12345') { raise } rescue nil

          audit.reload
          assert !audit.complete?
        end

        it 'does not perform when the audit is already complete' do
          audit = QueueAudit.find_by_enqueued_id('abc/1/12345')
          assert !audit.complete?
          MailQueueJob.around_perform_manage_audit('hello', "foo", 'abc/1/12345') {}
          assert audit.reload.complete?

          MailQueueJob.around_perform_manage_audit('hello', "foo", 'abc/1/12345') do
            assert false, 'Should not have been executed'
          end
        end

      end

      describe 'when requeue_immediately! requested' do
        before do
          MailQueueJob.requeue_immediately!
        end

        after do
          MailQueueJob.disable_requeue_immediately
        end

        it 're_enqueue_immediately? should return true' do
          assert MailQueueJob.requeue_immediately
        end

        it 'should call audit.re_enqueue_immediately! and set enqueue_count to 1' do
          audit = QueueAudit.find_by_enqueued_id('abc/1/12345')

          MailQueueJob.around_perform_manage_audit('hello', "foo", 'abc/1/12345') {}

          audit.reload
          assert_equal 1, audit.enqueue_count
        end

        it 'should not complete' do
          audit = QueueAudit.find_by_enqueued_id('abc/1/12345')
          assert !audit.complete?

          MailQueueJob.around_perform_manage_audit('hello', "foo", 'abc/1/12345') {}

          audit.reload
          assert !audit.complete?
        end

        it 'after the job finishes, requeue_immediately should set to false' do
          MailQueueJob.around_perform_manage_audit('hello', "foo", 'abc/1/12345') {}
          assert !MailQueueJob.requeue_immediately
        end
      end
    end

    describe 'background heartbeating' do
      before do
        QueueAudit.delete_all
        Resque.inline = true
      end

      after do
        Resque.inline = false
      end

      it 'heartbeats continously in the background' do
        time_travel = Time.now + 10.years
        BackgroundHeartbeatTestJob.enqueue(time_travel)
        assert_operator QueueAudit.first.timeout_at, :>, time_travel
      end
    end
  end
end
