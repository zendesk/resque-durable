[![Build Status](https://travis-ci.org/zendesk/resque-durable.png)](https://travis-ci.org/zendesk/resque-durable)
[![Dependencies](http://orgdeps.herokuapp.com/organizations/zendesk/repositories/resque-durable.svg?token=7f2805e330f6932a1754278d4161fe3f)](http://orgdeps.herokuapp.com/organizations/zendesk/repositories#resque-durable)


# What's this?

Resque/Durable allows important jobs to survive when a encountering a failure with Redis or the system in general.
It does this by adding traditional database-backed audits for durable jobs enqueued in Resque.

When an audited job isn't marked as complete after a certain amount of time (10 minutes by default),
it's considered failed, and will be re-enqueued with exponential backoff until it succeeds or is removed.

# Usage

See /examples

### Re-enqueuing gracefully

To re-enqueue the job gracefully, and without waiting for the the audit failure timeout, call the `requeue_immediately!` class method at any point while performing the job (usually at or close to the end).

Resque/Durable will not mark the job as complete. Instead, it will mark the job as failed and reset the exponential backoff. The background durable monitor will then re-enqueue the job as described above.

A common use case for this would be to gracefully stop a long-running job for a worker restart, and retry the job as soon as possible after the worker restart.

# When things go wrong

Audits stick around, and will be retried, until completed or expired by the monitoring script (expiration is configurable).
Due to the backoff delay, a typical job won't be retried more than 10 times in 24 hours, or 20 times in a week.

If a queue becomes backed up for too long, jobs may become double enqueued.
The first enqueued job will mark the audit as complete, and the second version of the job won't be worked on.
This strategy greatly reduces the possibility, but doesn't gaurentee, the same job isn't performed twice.

# License
MIT
