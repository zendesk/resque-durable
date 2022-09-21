require 'active_record'
require 'active_support/core_ext'

module Resque
  module Durable
    class QueueAudit < ActiveRecord::Base
      JobCollision = Class.new(StandardError)

      self.table_name = :durable_queue_audits
      # id
      # enqueued_id
      # queue_name
      # payload
      # enqueue_count
      # enqueued_at
      # completed_at
      # timeout_at
      # updated_at
      # created_at
      DEFAULT_DURATION = 10.minutes

      validates_length_of    :payload_before_type_cast, in: 1..(type_for_attribute('payload').limit)

      validates_inclusion_of :duration, :in => 1.minute.to_i..3.hours.to_i

      scope :older_than, ->(date) { where('created_at < ?', date) }

      scope :failed, -> {
        where(completed_at: nil)
          .where('timeout_at < ?', Time.now.utc)
          .order('timeout_at asc')
          .limit(500)
      }

      scope :complete, -> { where('completed_at is not null') }

      module Recovery

        def recover
          failed.each do |audit|
            begin
              audit.enqueue if audit.retryable?
            rescue => e
              message = "#{e.class.name}: #{e.message}\n#{(e.backtrace || []).join("\n")}"
              logger && logger.error("Failed to retry audit #{audit.enqueued_id}: #{message}")
            end
          end
        end

        def cleanup(date)
          older_than(date).destroy_all
        end

      end
      extend Recovery

      def self.initialize_by_klass_and_args(job_klass, args)
        new(:job_klass => job_klass, :payload => args, :enqueued_id => GUID.generate)
      end

      def job_klass
        read_attribute(:job_klass).constantize
      end

      def job_klass=(klass)
        write_attribute(:job_klass, klass.to_s)
      end

      def payload
        ActiveSupport::JSON.decode(super)
      end

      def payload=(value)
        super value.to_json
      end

      def queue
        Resque.queue_from_class(job_klass)
      end

      def enqueue
        job_klass.enqueue(*(payload.push(self)))
      end

      def duration
        job_klass.job_timeout
      end

      def heartbeat!
        update_attribute(:timeout_at, Time.now.utc + duration)
      end

      # Bumps the `timeout_at` column, but raises a `JobCollision` exception if
      # another process has changed the value, indicating we may have multiple
      # workers processing the same job.
      def optimistic_heartbeat!(last_timeout_at)
        next_timeout_at = Time.now.utc + duration
        nrows = self.class.
          where(id: id, timeout_at: last_timeout_at).
          update_all(timeout_at: next_timeout_at)
        raise JobCollision.new unless nrows == 1
        next_timeout_at
      end

      def fail!
        update_attribute(:timeout_at, Time.now.utc)
      end

      def enqueued!
        self.enqueued_at    = Time.now.utc
        self.timeout_at     = enqueued_at + duration
        self.enqueue_count += 1
        save!
      end

      def complete!
        self.completed_at = Time.now.utc
        save!
      end

      def complete?
        completed_at.present?
      end

      def retryable?
        Time.now.utc > (timeout_at + delay)
      end

      # 1, 8, 27, 64, 125, 216, etc. minutes.
      def delay
        (enqueue_count ** 3).minutes
      end

      def reset_backoff!(timeout_at = Time.now.utc)
        # Set timeout_at = Time.now and enqueue_count = 1 so
        # the job can be picked up by the Durable Monitor asap.
        self.timeout_at = timeout_at
        self.enqueue_count = 1
        save!
      end
    end
  end
end
