# Decisions and rationale

Each entry says what was decided, why, and what it costs. Newer entries replace older ones. IDs in brackets point to the question or conflict in the plan.

## Product and budget

- **Real product, 2 people, deadline about 3 Jan 2027.** Core workflow: taking notes. Triage is Must / Should / Could / Won't (plan section 5).
- **Budget $100, suspend at 3 months [M10].** About $28 to $32 of AWS usage a month means credits last a bit over 3 months. The free-plan account is closed when credits end, so data and keys are exported before suspension. Suspension date: [AWS account creation date + 3 months].

## Architecture

- **CloudFront in front of web and API, default `*.cloudfront.net` name [C-6].** One origin means SameSite cookies work and no CORS. No domain because there is no money. Cost: the hop to EC2 is plain HTTP, so EC2 accepts only the CloudFront prefix list plus a secret header; emailed links contain the CloudFront name.
- **Single EC2, RDS private, 3 S3 buckets (web, artifacts, notes), no load balancer.** Cheapest layout that meets the volume (about 50 users at launch).
- **Gmail SMTP with a pool of dedicated accounts by purpose (security, reminder, invite) [N-1, M2].** Free, no domain needed. Separate accounts so reminders can never block a password reset. Start at 100 emails a day each (new accounts are limited). Test-phase measure only. Outbox with priority and idempotency keys stays, so moving to SES or Resend later changes one worker.
- **Two reminders per event (X and start) [6.4].** Saves email quota. Rough size: 50 users x 10 events a month is about 200 reminder emails a day.
- **Notes bucket versioning off [M6].** Versioning would keep "purged" notes on disk and break the retention promise. RDS backups (7 days) remain, and the privacy text says purged data can live in backups that long.

## Data

- **PostgreSQL 16, UUID ids, timestamptz + IANA timezone.** Event times are one instant plus the event's own zone; reminders use the recipient's zone.
- **Prisma ORM, SQL first.** `schema.sql` is the source of truth and becomes migration 0001. PART 1 (tables) is modelled by Prisma; PART 2 (partial unique indexes, triggers, functions) is raw SQL Prisma does not touch. Why: the schema depends on database features (one active session, one active subscription, retention stamps, locks) that an ORM-only schema cannot express. Risk: a generated migration could drop one of them, so every migration is read before merge and CI compares migrations with `schema.prisma`. Not verified: Prisma itself was not run when this was written (its engine download was blocked); steps 4-7 of the plan are the first test.
- **Tags: plain unique `tg_name` column, integer ids.** A generated column and bigint ids do not suit Prisma.
- **Email and username plaintext [C-4]; names, phone, birth date, address and note files encrypted (AES-256-GCM).** Email is the sign-in key. Trade-off: a leaked database shows who the users are.
- **Notes are encrypted `.md` files in S3, under 2 MB, title plaintext and searchable [C-3].** Highlight is `==text==` through a TipTap Markdown editor, sanitized on display [M5].
- **Retention per object (account, workspace, note, event), 15 days by default [C-7].** Stored in `retention_policy`; the value is stamped on the row at deletion, so changes affect future deletions only. The purge job deletes S3 files first, then rows.
- **Phone field stays on the sign-up form [M1].** Optional and encrypted. Nothing uses it in v1 (SMS was cut); the privacy text must say so.
- **Predefined tags only, 12 seeded [M9].** Adding one needs a migration.

## Security and sessions

- **One active session per user, newest sign-in wins [C-1, N-8, N-10].** Enforced by a partial unique index and one transaction. The JWT carries the session id and every request checks the session row, otherwise a signed-out device works for up to 30 minutes.
- **Neutral messages [C-2].** Never reveal whether an account or email exists; connection or server problems may be named.
- **Lockout 10 failures for 24 h; OTP 8 chars, 15 min, 3 attempts, 2 min resend, 20 per hour.**
- **reCAPTCHA on sign in and sign up [N-3].** Free tier is 10,000 assessments a month with no billing. If it is unreachable or over quota: block sign up, allow sign in [M7].

## Collaboration

- **Invites are email-bound and single-use [C-5, N-2].** Only the signed-in, verified account with the invited email can redeem, once; valid until the event ends, 30 days at most [C-9]. A wrong account does not burn the link. No copy-link option. Quota: 20 a day per organizer, 50 per event, verified organizers only [M3].
- **Events up to 30 days [N-7]; 999 subscribers plus the organizer.**
- **Note locks, per note [M4, N-11].** Opening a note occupies it until you leave, viewers like editors; heartbeat every 30 s, 2 min timeout; the workspace owner can take over; a revoked session frees its locks. v1 only; later versions may allow shared reading. The lock is a courtesy: permission and `n_version` checks still run on every save.

## Process

- **Environments are pipeline stages:** Dev (local Docker), Test (CI with a throwaway Postgres), Staging (optional), Production (one AWS stack).
- **Migrations run from EC2**, because RDS is private and CI cannot reach it.
- **Definition of done includes loading, empty and error states and the decision note [N-6].**
- **README, TODO and NOTES are regenerated from the plan [M8].**

## Placeholders still to fill

[AWS account creation date], [repo name], [Prisma version], [Terraform or AWS CDK], [Secrets Manager or Parameter Store path], [owner of the export], [team contact].


## Rony's Remarks
yaml should be used for documentation 