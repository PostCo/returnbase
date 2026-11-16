# 1. Solid Queue on Postgres for background jobs

Date: 2026-02-09

## Status

Accepted

## Context

Returnbase needs background jobs from the first integration on: sending returns to a warehouse without holding up the merchant's click, and checking vendors for updates on a schedule. The usual Rails answer is Sidekiq with Redis.

Everyone runs the whole stack locally with one `bin/setup`, and CI builds it from nothing on every pull request. Each extra service is one more container to start, health-check and explain when it fails. Our volume is small: tens of jobs a minute, not thousands.

## Decision

Jobs run on Solid Queue, with its tables in the main Postgres database (`config.active_job.queue_adapter = :solid_queue` in `config/application.rb`). The `worker` service runs `bin/jobs`, which starts the dispatcher, the worker and the scheduler (`config/queue.yml`). Recurring jobs are listed in `config/recurring.yml`. The scheduler reads that file when the worker starts, so a new or changed entry needs `docker compose restart worker`.

Jobs stay thin: a job loads its record and calls one service. `ApplicationJob` has no automatic retries, so each service decides what a failure leaves behind.

## Consequences

- Setup has one database. `bin/reset` clears queued jobs along with everything else.
- The queue shares the app's transactions. A job enqueued inside a transaction that rolls back never runs, so an approval that fails never sends anything.
- There is no Sidekiq dashboard. Look at the `solid_queue_*` tables or `docker compose logs worker`.
- A failed job is not retried. Where a failure matters, the service records it (see [0006](0006-recording-failed-storebox-sends.md)).
- If the job volume grows by orders of magnitude, revisit this before tuning Postgres around it.
