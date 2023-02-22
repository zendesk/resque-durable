require 'thread'

module Resque
  module Durable

    # Creates a background thread to regularly heartbeat the queue audit.
    class BackgroundHeartbeat

      def initialize(queue_audit, interval)
        @queue_audit  = queue_audit
        @last_timeout = nil
        @interval     = interval
        @mutex        = Mutex.new
        @cv           = ConditionVariable.new
        @stop         = false
        @thread       = nil
      end

      class << self
        # only a separate method for easy stubbing
        def exit_now!
          abort
        end
      end

      def with_heartbeat
        start!
        yield
      ensure
        stop_and_wait!
      end

      def heartbeat!
        @last_timeout ||= @queue_audit.timeout_at
        @last_timeout = @queue_audit.optimistic_heartbeat!(@last_timeout)
      rescue StandardError => e
        @queue_audit.logger.error("Exception in BackgroundHeartbeat thread: #{e.class.name}: #{e.message}")
        self.class.exit_now!
      ensure
        ActiveRecord::Base.clear_active_connections!
      end

      def start!
        raise "Thread is already running!" if @thread
        @stop = false

        # Perform immediately to reduce heartbeat race condition opportunities
        heartbeat!

        @thread = Thread.new do
          while !@stop
            heartbeat!

            @mutex.synchronize do
              end_at = monotonic_now + @interval
              while !@stop && monotonic_now < end_at
                sleep_for = end_at - monotonic_now
                @cv.wait(@mutex, sleep_for)
              end
            end
          end
        end
      end

      def stop_and_wait!
        return unless @thread
        signal_stop!
        # Prevent deadlock if called by the `heartbeat` thread, which can't wait for itself to die.
        return if @thread == Thread.current
        @thread.join
        @thread = nil
      end

      # Signal the `heartbeat` thread to stop looping immediately. Safe to be call from any thread.
      def signal_stop!
        return unless @thread
        @mutex.synchronize do
          @stop = true
          @cv.broadcast
        end
      end

      private

      def monotonic_now
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end
  end
end
