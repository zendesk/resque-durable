require_relative './test_helper'

module Resque::Durable
  class QueueAuditTest < Minitest::Test

    describe 'Queue Audit' do
      after do
        QueueAudit.delete_all
      end

      before do
        @queue = MailQueue
        @queue.data = []

        @audit = QueueAudit.initialize_by_klass_and_args(MailQueueJob, [ 'hello' ])
      end

      describe 'recover' do

        describe 'failing to retry' do
          before do
            @good_audit = QueueAudit.initialize_by_klass_and_args(MailQueueJob, [ 'good' ])
            @good_audit.stubs(:retryable?).returns(true)

            @bad_audit  = QueueAudit.initialize_by_klass_and_args(MailQueueJob, [ 'bad' ])
            @bad_audit.stubs(:retryable?).returns(true)
            @bad_audit.expects(:enqueue).raises('Boom!')

            QueueAudit.stubs(:failed).returns([ @good_audit, @bad_audit ])
          end

          it 'does not stop retrying other jobs' do
            @good_audit.expects(:enqueue)
            QueueAudit.recover
          end

          it 'records the failure' do
            QueueAudit.logger.expects(:error)
            QueueAudit.recover
          end
        end
      end

      describe 'save!' do
        it 'generates a UUID' do
          @audit.save!
          assert @audit.enqueued_id
        end
      end

      describe 'complete!' do
        it 'updates the completed timestamp' do
          @audit.save!
          assert !@audit.completed_at?
          assert !@audit.complete?
          Timecop.freeze(Time.now) do
            @audit.complete!

            assert_equal Time.now, @audit.completed_at
            assert_equal true,     @audit.complete?
          end
        end

      end

      describe 'older than' do
        before do
          Timecop.freeze(24.hours.ago) do
            @audit.save!
          end
        end

        it 'provides audits older than the given date' do
          assert_equal [ @audit ], QueueAudit.older_than(23.hours.ago)
        end

        it 'does not provide audits newer than the given date' do
          assert_equal [], QueueAudit.older_than(25.hours.ago)
        end

      end

      describe 'failed' do
        before do
          @audit.enqueued!
          @audit.reload
        end

        it 'provides audits enqueued for more than than the expected run duration' do
          Timecop.freeze(@audit.timeout_at + 1.second) do
            assert_equal [ @audit ], QueueAudit.failed.to_a
          end
        end

        it 'does not provide audits enqueued less than the expected run duration' do
          Timecop.freeze(@audit.timeout_at - 1.second) do
            assert_equal [], QueueAudit.failed
          end
        end

      end

      describe '#payload' do
        subject do
          @audit.payload
        end

        describe 'without data present' do
          before do
            @audit[:payload] = ''
          end

          it { expect(subject).must_be_nil }
        end

        describe 'with JSON data available' do
          before do
            @audit[:payload] = \
              { test: 'data' }.to_json
          end

          it 'returns as decoded' do
            expect(subject).must_equal \
              ({ 'test' => 'data' })
          end
        end
      end

      describe 'enqueue' do
        it 'sends the payload to the queue' do
          Resque.expects(:enqueue).with(MailQueueJob, 'hello', @audit.enqueued_id)
          @audit.enqueue
        end
      end

      describe 'enqueued!' do

        it 'increments the enqueue count' do
          assert_equal 0, @audit.enqueue_count
          @audit.enqueued!
          assert_equal 1, @audit.enqueue_count
        end

        it 'updates the enqueued timestamp' do
          an_hour_ago = 1.hour.ago
          Timecop.freeze(an_hour_ago) do
            @audit.enqueued!
          end

          assert_equal an_hour_ago, @audit.enqueued_at
        end

      end

      describe 'before_perform' do
        it 'updates the timeout' do
          an_hour_ago = 1.hour.ago
          Timecop.freeze(an_hour_ago) do
            @audit.enqueued!
          end

          assert_equal (an_hour_ago + 10.minutes), @audit.timeout_at
        end

        it 'allows configuration of the timeout' do
          MailQueueJob.job_timeout = 1.hour
          an_hour_ago = 1.hour.ago
          Timecop.freeze(an_hour_ago) do
            @audit.enqueued!
          end
          assert_equal (an_hour_ago + 1.hour).to_i, @audit.timeout_at.to_i
          MailQueueJob.job_timeout = 10.minutes
        end
      end


      describe '#retryable?' do
        subject do
          @audit.retryable?
        end

        it 'checks if the expected run duration with delay is exceeded' do
          @audit.enqueued!
          assert_equal 1.minute,   @audit.delay
          assert_equal 10.minutes, @audit.duration
          assert_equal false, subject

          Timecop.freeze(Time.now + 10.minutes) do
            assert_equal false, @audit.retryable?
          end

          Timecop.freeze(Time.now + 11.minutes) do
            assert_equal true, @audit.retryable?
          end

          Timecop.freeze(1.year.from_now) do
            assert_equal true, @audit.retryable?
          end
        end

        describe 'without :timeout_at value' do
          before do
            @audit[:timeout_at] = ''
          end

          it 'is always false' do
            expect(subject).must_equal false
          end
        end
      end

      describe 'heartbeat!' do
        it 'extends the timeout_at timestamp' do
          ts = 1.hour.ago
          Timecop.freeze(ts) do
            @audit.enqueued!
          end
          assert_equal ts + 10.minutes, @audit.timeout_at

          ts = 30.minutes.ago
          Timecop.freeze(ts) do
            @audit.heartbeat!
          end
          assert_equal ts + 10.minutes, @audit.timeout_at
        end
      end

      describe 'optimistic_heartbeat!' do
        before do
          @audit.save!
          @audit.heartbeat!
        end
        describe 'with a correct current value' do
          it 'updates the database and returns the new value' do
            Timecop.freeze do
              new_timeout_at = @audit.optimistic_heartbeat!(@audit.timeout_at)
              assert_equal(Time.now.utc + @audit.duration, new_timeout_at)
              @audit.reload
              # `round` is due to sqlite losing precision on some platforms
              assert_equal(new_timeout_at.round, @audit.timeout_at.round)
            end
          end
        end

        describe 'with an incorrect current value' do
          it 'raises JobCollision' do
            assert_raises Resque::Durable::QueueAudit::JobCollision do
              @audit.optimistic_heartbeat!(@audit.timeout_at + 1.second)
            end
          end
        end
      end

      it 'has an exponential delay based on enqueue attempts' do
        @audit.enqueued!
        assert_equal 1.minute,   @audit.delay

        @audit.enqueued!
        assert_equal 8.minutes,  @audit.delay

        @audit.enqueued!
        assert_equal 27.minutes, @audit.delay
      end

      describe 'reset_backoff!' do
        before do
          Timecop.freeze(Time.now.utc + 1.minute)
          @timeout_at = Time.now.utc
          @audit.reset_backoff!(@timeout_at)
          @audit.reload
        end

        after do
          Timecop.return
        end

        it 'should change the timeout_at value' do
          assert_equal @timeout_at.round, @audit.timeout_at.round
        end

        it 'provides audits enqueued for more than the expected run duration' do
          Timecop.freeze(@audit.timeout_at + 1.minutes) do
            assert_equal [ @audit ], QueueAudit.failed.to_a
          end
        end

        it 'should set the enqueue_count value to 1' do
          assert_equal 1, @audit.enqueue_count
        end
      end
    end

  end
end
