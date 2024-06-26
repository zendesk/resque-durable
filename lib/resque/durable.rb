module Resque
  module Durable
    autoload :GUID,       'resque/durable/guid'
    autoload :Monitor,    'resque/durable/monitor'
    autoload :QueueAudit, 'resque/durable/queue_audit'
    autoload :BackgroundHeartbeat, 'resque/durable/background_heartbeat'

    def self.extended(base)
      # The duration since the last heartbeat that the monitor will wait before
      # re-enqueing the job.
      base.cattr_accessor :job_timeout
      base.job_timeout = 10.minutes

      # How frequently a background thread will optimistically heartbeat the
      # QueueAudit. Value must be smaller than job_timeout. Currently opt-in.
      #
      # Recommended value: `15.seconds`
      base.cattr_accessor :background_heartbeat_interval

      base.cattr_accessor :auditor
      base.auditor = QueueAudit
    end

    def enqueue(*args)
      if args.last.is_a?(auditor)
        # the audit-is-re-enqueing case
        audit = args.pop
      else
        audit = build_audit(args)
      end

      args << audit.enqueued_id
      begin
        audit.enqueued!
      rescue Exception => e
        audit_failed(e, args)
      end

      Resque.enqueue(self, *args)
    rescue Exception => e
      enqueue_failed(e, args)
    end

    def audit(args)
      audit = auditor.find_by_enqueued_id(args.last)
      audit_failed(ArgumentError.new("Could not find audit: #{args.last}")) if audit.nil?
      audit
    end

    def heartbeat(args)
      if a = audit(args)
        a.heartbeat!
      end
    end

    def around_perform_manage_audit(*args)
      if a = audit(args)
        return if a.complete?
        if background_heartbeat_interval
          raise "background_heartbeat_interval (#{background_heartbeat_interval.inspect}) be smaller than job_timeout (#{job_timeout.inspect})" if background_heartbeat_interval >= job_timeout
          BackgroundHeartbeat.new(audit(args), background_heartbeat_interval).with_heartbeat do
            yield
          end
        else
          a.heartbeat!
          yield
        end

        if requeue_immediately
          a.reset_backoff!
        else
          a.complete!
        end
      else
        yield
      end
    ensure
      @requeue_immediately = false
    end

    def requeue_immediately
      @requeue_immediately
    end

    def requeue_immediately!
      @requeue_immediately = true
    end

    def disable_requeue_immediately
      @requeue_immediately = false
    end

    def build_audit(args)
      auditor.initialize_by_klass_and_args(self, args)
    end

    def audit_failed(e, args)
      raise e
    end

    def enqueue_failed(e, args)
      raise e
    end

  end
end
