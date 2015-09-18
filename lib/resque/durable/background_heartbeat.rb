require 'thread'

module Resque
  module Durable

    # Creates a background thread to regularly heartbeat the queue audit.
    class BackgroundHeartbeat
      DEFAULT_INTERVAL = 15

      def initialize(queue_audit, interval = nil)
        @queue_audit  = queue_audit
        @last_timeout = nil
        @interval     = interval || DEFAULT_INTERVAL
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
              @cv.wait(@mutex, @interval)
            end
          end
        end
      end

      def stop_and_wait!
        return unless @thread
        # Prevent deadlock if called by the `heartbeat` thread, which can't wait for itself to die.
        return signal_stop! if @thread == Thread.current
        while @thread.alive?
          signal_stop!
          sleep 0.01
        end
        @thread.join
        @thread = nil
      end

      # Signal the `heartbeat` thread to stop looping immediately. Safe to be call from any thread.
      def signal_stop!
        @mutex.synchronize do
          @stop = true
          @cv.signal
        end
      end
    end
  end
end
