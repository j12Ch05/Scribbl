# Scribbl Week: Project Plan (revision 5, final)

Status: **final**. All questions from rounds 1 to 4 are answered. This revision applies `after_review_3.md` to `schema.sql` (now Prisma-compatible, tested on PostgreSQL 16), `Scribbl.drawio` (your layout kept) and this plan, and adds the numbered action steps in section 9.
**C-n** = conflict between two answers (settled). **M-n** = round-4 question (settled in section 8).

## What changed in revision 5

- **Prisma ORM** is the data-access layer. `schema.sql` is split into PART 1 (tables, modelled by Prisma), PART 2 (partial unique indexes, triggers, functions: raw SQL kept in the migration) and PART 3 (seeds). See 4.8.
- **Locking is per note, not per workspace** (M4). Viewers occupy a note like editors. The workspace owner can take over. New `note_locks` table replaces `workspace_locks`.
- **Phone field stays on the sign-up form** (M1), optional and encrypted. Nothing uses it in v1.
- **Suspend at 3 months** (M10). A data export outside AWS is part of the plan because the free-plan account closes when credits end.
- Defaults accepted for M2, M3, M5, M6, M7, M8, M9 (section 8). The 12 seeded tags are final. Gmail accounts start at 100 emails a day.
- `tags.tg_name` is a plain unique column; tag and mail-account ids are integers (Prisma-friendly).

---

## 1. Product summary

Scribbl Week lets people write notes, schedule events, and get email reminders. A note can reference an event ("Write it, Schedule it, Done").

- Type: real product. Deadline: 2 months from 3 Nov 2026, so about 3 Jan 2027. Team: 2 people (P and J).
- Target users: managers, note takers, students. Core workflow to make excellent: **taking notes**.
- MVP success: a user can create workspaces, notes and events, and subscribers receive alerts for those events.
- Budget: never more than $100 in total. **The product is suspended at 3 months of AWS usage**, counted from [AWS account creation date] (suspension date: [AWS account creation date + 3 months]), or earlier if the credits run out. It stays suspended until sponsorship (M10).

| # | Criterion | Target |
|---|---|---|
| S1 | New user signs up, verifies, creates a workspace and a note | under 3 minutes |
| S2 | Note save (autosave) completes | p95 under 1.5 s |
| S3 | Reminder email is handed to Gmail | within 60 s of its scheduled time, 99% |
| S4 | Reminder is never sent twice to the same person | 0 duplicates |
| S5 | AWS **usage** (credits consumed), not cash | alerts at $25 / $50 / $80 of usage, hard cap $100. Cash charged to a card: $0 |

**Your question on S5: is $25 credits or real money?** It means the dollar value of AWS services you have *used*, which is what draws down your credits. My wording was unclear. With a new-account free plan you pay no cash: the plan lasts 6 months or until the credits run out, then the account is closed instead of billed ([AWS Builder Center](https://builder.aws.com/content/3Kkt4kNiDSUnO3n6db2weSNubzE/the-dollar0-aws-account-in-2026-free-plan-credits-guardrails)). Cash only appears if you upgrade to a paid plan. Two practical points:
1. Create the budgets so they count gross usage and do **not** subtract credits; otherwise the number would stay at $0 while credits quietly absorb the bill. AWS Budgets lets you choose which cost types a budget includes. I have not checked the exact option names in your console, so confirm there.
2. Add one more alert at about $1 of **actual charges**, so you hear immediately if anything ever bills real money.

---

## 2. Decisions now locked

| Area | Decision |
|---|---|
| Stack | React.js, NestJS (REST, versioned `/api/v1`), PostgreSQL 16 on RDS, **Prisma ORM** (Client + Migrate) |
| Data access | Prisma Client for normal queries; `$queryRaw` for locks, invite redeem, `FOR UPDATE`, `SKIP LOCKED`, Gmail account choice. `schema.sql` is the source of truth for the database (4.8) |
| Hosting | S3 + CloudFront (web, default `*.cloudfront.net` name), EC2 single instance (API), RDS free-tier instance, no load balancer. **3 buckets**: web, API releases, notes |
| Email | Gmail SMTP (app passwords) through a **pool of dedicated accounts** by purpose: security, reminder, invite (v1 stop-gap, N-1). Resend and SMS are cut |
| IDs | UUIDs |
| Auth | argon2id/bcrypt; JWT in httpOnly cookies; access 30 min, refresh 60 days; **one active session per user**, newest sign-in wins (C-1, N-8) |
| Password rules | 8+ chars, at least one upper, lower, digit, symbol |
| OTP | 8 chars, 15 min, 3 attempts, resend after 2 min, 20 requests/hour per IP and per email |
| Lockout | 10 failed sign-ins lock the account 24 h. reCAPTCHA on sign in and sign up (N-3) |
| Verification | email link only, valid 15 min, can be re-requested. Unverified users can sign in (banner, cannot subscribe, no emails except verification) |
| Deletion | Recovery period **configurable per object type**, 15 days by default (C-7). Then purged (S3 files first, then rows) |
| Username (handle) | not unique, changeable once per 7 days |
| Encryption | first/last name, phone, birth date, address and note files encrypted. **Email and username are plaintext** |
| Notes | encrypted `.md` file in S3, < 2 MB, title plaintext and searchable (C-3). Editor: a rich editor that saves Markdown (TipTap with the Markdown extension); highlight is `==text==`, sanitized on display (M5) |
| Autosave | 10 s after typing stops; browser-close save is a best-effort attempt plus a local draft |
| Workspaces | owner has all rights; owner adds people by exact email, they accept; `read` or `write`; only the owner deletes. 9999 notes / workspace, 999 workspaces / user |
| Events | any user; not tied to a workspace; up to **30 days**. Start = one timestamp + duration, timezone stored per event |
| Event capacity | 999 subscribers + organizer = 1000 |
| Invites | organizer adds an invitee email, an email with a link is sent. The link is **bound to that email and single-use**: only the signed-in, verified account with that email can redeem it, once. Valid until the event ends, 30 days at most, hash stored |
| Reminders | 2 emails per event: X before and at start, in each user's timezone |
| Note use (v1) | opening a **note** (edit or view) occupies it until the user leaves; a viewer occupies it like an editor; others see who is in it. The workspace owner can take over. Heartbeat every ~30 s, 2 min timeout, released on session revoke (N-11, M4) |
| Sign-up form | name, surname, email, **phone (optional, encrypted)**, address, password, birth date, handle, TOS, CAPTCHA (M1) |
| Invite limits | verified organizers only; 20 invites a day per organizer, 50 per event (M3) |
| reCAPTCHA failure | if the check is unreachable or over quota: block sign up, allow sign in (lockout still applies) (M7) |
| Gmail pool | 1 security + 1 reminder + 1 invite account to begin; `ma_daily_limit` 100 each, raised later (M2) |
| Suspension | at 3 months of AWS usage; export data outside AWS first (M10, step 49) |
| Tags | the 12 seeded tags only (M9); one tag appears at most once per workspace or event; jsonb `{name, color, description}` |
| Accessibility | WCAG 2.1 AA baseline + toggles: high contrast, large text, reduced motion |
| Languages | English, French, Arabic via i18n files bundled with the frontend. Arabic right-to-left is "Could" |
| Home page | today's events, next 7 days, recent notes, New Note / New Event buttons |
| Environments | pipeline stages: Dev (local Docker), Test (CI), Staging (optional), Production (one AWS stack) |
| Testing | unit tests per module, then module tests on the whole system |

---

## 3. Review of your answers

### 3.1 Conflicts: how your answers were applied

| ID | Your answer | Applied |
|---|---|---|
| C-1 | Latest login gets the account, the previous login is logged out | One active session per user. New sign-in revokes the old session in the same transaction; the old device sees "you signed in on another device". |
| C-2 | Neutral message | Never reveal whether an account or email exists (sign in, forgot password, invite, workspace add). Connection/server problems may be named. |
| C-3 | `.md` | `.md` only; `n_format` removed. |
| C-4 | Email not encrypted | Plaintext email. |
| C-5 / N-2 | Email-bound single-use link supersedes every earlier wording | `ei_invitee_email` is NOT NULL; redeem requires the signed-in verified email to match; copy-link removed from the diagram, schema and template. |
| C-6 | Still discussing (domain) | Design works with none. |
| C-7 | Retention configurable per major object, 15 days default | `retention_policy` + `*_purge_after`, stamped when the item is deleted. |
| C-8 | SMTP | Gmail SMTP, with the account pool (N-1). |
| C-9 | Invite valid until the event ends | Done, 30-day cap. |

### 3.2 Critiques of the new decisions (revision 4)

**Gmail account pool (N-1).** Your design is sound as a stop-gap: separate accounts so reminders can never block a password reset. Points to know:
- Each account needs its own 2-Step Verification (usually phone-verified) and app password. Creating many accounts to get around limits can look like abuse to Google; if one is suspended you lose its mail. Treat the pool as 3 to 5 accounts, not a growth plan.
- Limits are per account and rolling 24 h; new accounts may be held to roughly 100 to 200 recipients a day ([serversmtp.com](https://serversmtp.com/limits-of-gmail-smtp-server/)). `ma_daily_limit` defaults to **100** (M2); raise it once an account has history.
- You do not need to maintain a `used_list`: `pick_mail_account(purpose)` computes it from what was sent in the last 24 h, skips disabled accounts and accounts Gmail itself refused (`ma_exhausted_until`), and returns the least-used one. When all are used, mail stays pending and is retried on the next poll.
- App passwords must not sit in the database. `ma_secret_ref` names an AWS Secrets Manager / SSM parameter.
- Mail from different accounts shows different From addresses; expect some in spam. Fine for testing.
- Real size check with your section 6.3 numbers: 50 users x 10 events a month is about 17 events a day, each about 6 recipients x 2 reminders = about 200 reminder emails a day. **One reminder account is enough at launch**; the pool is insurance.

**Backups option A conflicts with your retention rules.** Option A said "S3 versioning on the notes bucket, 30-day rule for old versions". With versioning, a purged or "Delete now" note still exists as an old version, so the 15-day promise and the privacy text would be false. Fix (M6, accepted): no versioning on the notes bucket, or expire non-current versions after 1 day; keep RDS backups (7 days) and say in the privacy text that purged data can live in backups up to 7 days. The purge job must delete the S3 object before the row.

**One active session.**
- The JWT must carry the session id and **every request checks the session row** (one indexed lookup); otherwise the logged-out device keeps working for up to 30 minutes.
- Two sign-ins at the same moment: the partial unique index makes one fail; the API retries. Both cannot end up active.
- Consequences to accept: you cannot be signed in on laptop and phone together; shared family accounts will fight. Show a clear message on the old device.
- Revoking a session also releases its note locks (trigger in the schema).

**Note occupancy (v1, M4).** The lock is per note: opening a note occupies it until you leave, a viewer occupies it like an editor, and the workspace owner can take over.
- A closed laptop or lost connection would block a note forever. Heartbeat every ~30 s and a 2-minute timeout free it (`acquire_note_lock`).
- Take-over (`take_over_note_lock`) works only for the owner of the note's workspace. The displaced user finds out on the next heartbeat; the editor must keep their unsaved text as a local draft so nothing is lost.
- Because viewers occupy too, two people cannot even read the same note at once in v1. Plan to relax it later (shared read).
- The lock is a courtesy, not security: the API still checks permissions and `n_version` on every save.
- Revoking a session frees its locks (trigger).

**Email-bound invites: new risks.**
- The organizer can make the app email any address. This is a spam path and burns Gmail quota. Decided (M3): only verified organizers, 20 invites a day per organizer, 50 per event, neutral reply, rate limit by IP.
- A person who changes their email loses pending invites; the organizer re-invites.
- An invitee with no account signs up with that exact email (verified) and then opens the link. State this on the invite page.
- A wrong account gets a message and the link is **not** burned (tested).

**reCAPTCHA.** The free tier is 10,000 assessments a month per organization and needs no billing; after that, calls return 429 unless billing is enabled ([Google Cloud](https://docs.cloud.google.com/recaptcha/docs/billing-information)). That is about 330 a day: plenty at launch. Decided (M7): if the check fails or is unreachable, block sign up and allow sign in (lockout still protects). Add your `*.cloudfront.net` hostname to the key's allowed domains and test in week 0.

**Retention per object.** Editable in `retention_policy`, but the value is stamped when the item is deleted, so changing it affects future deletions only. Account purge must also purge owned workspaces, notes and S3 files; make that one job with a dry run (R-14).

**Credits vs calendar.** At about $28 to $32 of usage a month, $100 lasts roughly 3 months: past your 3 Jan deadline but well before the 6-month plan end. Decided (M10): suspend at 3 months. Because the free-plan account is closed when credits end, export the data to somewhere outside AWS before that date (step 49).

**Prisma ORM.** Good fit for NestJS and TypeScript types, with three things to respect:
- Prisma does not model triggers, functions or CHECK constraints. They live in `schema.sql` (PART 2 and inline) and are replayed by the migration. Mirror every CHECK in the DTO validation so users get a clean message instead of a database error.
- Partial unique indexes are the dangerous part: `one_active_session_per_user`, `one_active_subscription`, `one_pending_invite_per_email`. Current Prisma documentation lists partial indexes (a `where` argument) as supported ([Prisma docs](https://www.prisma.io/docs/orm/prisma-schema/data-model/unsupported-database-features)); older versions introspect them as plain unique indexes. A plain unique on `sessions(u_id)` would make every second sign-in fail forever. Step 5 and the CI check in step 10 guard against it.
- RDS is in a private subnet, so GitHub Actions cannot run migrations. The deploy script on EC2 runs `prisma migrate deploy` (step 14).
- **Not verified:** I could not run Prisma itself in my workspace (its engine download is blocked), so the SQL was tested in plain PostgreSQL 16 only. Steps 4 to 7 are the first real test; do them before writing features.

### 3.3 Earlier critiques (still valid, shortened)

**Gmail SMTP.** It is free and needs no domain, but:
- The limit is about **500 recipients per day** for a personal Gmail account (2,000 for Google Workspace), counted per recipient on a rolling window; exceeded mail is rejected for up to 24 hours and Google may suspend SMTP for unusual sending ([serversmtp.com](https://serversmtp.com/limits-of-gmail-smtp-server/)). An app password requires 2-Step Verification on the account; plain password sign-in is gone.
- Every email counts: verification, OTP, invites, edit notices **and** reminders. One organizer with 200 subscribers sends 600 reminders in a day. A full event (1000) is 3,000 emails and is simply not deliverable on this limit.
- Mitigation built into the design: the outbox has an `eo_priority` column (1 = OTP / verification, 3 = invites and notices, 5 = reminders). The worker counts what it sent in the last 24 h and stops at the budget (proposal: 450), so security mail always gets through. Overflow reminders wait, which may mean late.
- Use a **dedicated** Gmail account for the app, not anyone's personal one. If it is suspended you must not lose your own inbox.
- No delivery webhooks: you only know the SMTP server accepted the message. Bounces land in that Gmail inbox.
- Emails come from `something@gmail.com`; that looks informal and is fine for an MVP, not for a launch.
- Keep the outbox table: moving to Resend or Amazon SES later is a change in one worker.
- Decide now what happens at the limit (N-1).

**No domain.** Options, with the one I recommend:

| Option | HTTPS | Cost | Problem |
|---|---|---|---|
| A (recommended): CloudFront default name | free, browser to CloudFront | $0 | CloudFront to EC2 hop is plain HTTP (you cannot get a public certificate for an `ec2-...amazonaws.com` name). Emailed links contain the CloudFront name, so deleting the distribution breaks old links. |
| B: free subdomain (for example DuckDNS) pointing to EC2 + Let's Encrypt on nginx | end to end | $0 | A third party you do not control; check it works with CloudFront as origin. |
| C: buy a domain | end to end, plus own sender address later | about $10 to $15 / year | Costs money now. |
For A: allow EC2 inbound only from the CloudFront prefix list, and add a secret header that CloudFront sends and nginx requires, so nobody can call the API directly. Record this as risk R-12. Also check that your CAPTCHA provider accepts a `*.cloudfront.net` hostname before you commit to one (N-3).

**Trash (15-day recovery for everything).** Good for users, but it adds work:
- New: Trash page, restore flows, nightly purge job that also deletes S3 files, and rules for what each restore does.
- Event delete: cancel reminders and email subscribers; event restore: re-create the reminders and email subscribers again. Invites stop working while trashed.
- Workspace delete hides its notes; restoring brings them back. A note deleted alone has its own timer.
- Counts (9999 notes, 999 workspaces) must ignore trashed rows.
- Account deletion trashes the owned workspaces and organized events with it (default Q-6).
- Add a "Delete now" button so a user can erase something immediately. Without it, "deleted" personal data lives 15 more days.
- Estimate about 4 to 5 extra days. It is placed in "Should" with the delete itself (soft delete column) in "Must".

**Refresh tokens.**
- Refresh-token rotation breaks when two tabs refresh at the same moment: the second one looks like a replayed token and would revoke the session. Allow a short grace period (about 10 s) for the previous token, or do not rotate. Risk R-15.
- It does not solve two *people* editing one note. The `n_version` check still decides.

**Adding people by email ("the owner searches for the email").**
- Use exact match only, no partial search or autocomplete, or the feature becomes a way to list your users' emails.
- Reply the same way whether or not the email has an account ("If that person has an account they will receive an invitation"), and rate-limit it.
- The person must accept; `workspace_members.wm_accepted_at` is empty while the invitation is pending. An email with no account gets no mail in v1.
- The same rules apply to the event invite list. There the organizer sees the entered emails and status (pending, used, revoked).

**Phone number.** Kept on the sign-up form (M1), optional and encrypted. Nothing uses it in v1; keep the privacy text honest about that, and do not make it required.

**Predefined tags.** I seeded 12 tags (your 4 + Meeting, Project, Ideas, Health, Finance, Travel, Family, Reminder). Edit freely; the list is final for v1 (M9); adding one later needs a migration. Hover text needs a tap alternative on touch.

**Multi-day events.** Max is 30 days (N-7). The calendar needs a way to draw an event over several days (a bar across day columns). Reminder "start" still fires once at the start.

**Plan template estimates and ownership (your edits).**
- The estimates add up to about 27 days for J and 22 days for P, which looks comfortable in 8 weeks, but several are very low: calendar with overlap layout in 2 days, reminders plus outbox in 2 days, encryption plus S3 in 3 days, sign up / in / reset in 3 days each including frontend and backend.
- **Nothing is estimated for AWS, CI/CD, IaC, deployment or testing**, although P owns infrastructure and J owns testing. Added as US-25 and US-26 so they show up.
- The `Owner` column mixes roles: P owns backend and J owns frontend, yet US-01 to US-04 (frontend and backend) are all J's. Decide whether Owner means "builds the whole feature" or "main person". The reviewer rule (the other person) is fine either way.
- If the 2 months count from 3 Nov, weeks 7 and 8 fall on 21 Dec to 3 Jan. If holidays apply to you, expect less capacity. Dates are added to the milestone table.
- In the definition of done, two boxes are unchecked: loading/empty/error states and the docs/decision note. If that is intentional, the Page States diagram and US-21 are no longer enforceable. (N-6 answered "default": keep them in the definition of done, so tick the unticked box when the work is done.)

---

## 4. Answers to the questions you asked back

### 4.1 Salt and hash
Modern hashes (argon2id, bcrypt) write the salt and cost settings into the output string, for example `$argon2id$v=19$m=65536,t=3,p=4$<salt>$<hash>`. One column, `us_password_hash`, holds everything. A separate seed/salt column is redundant. Use a maintained library, never your own construction.

### 4.2 Logout and revocation
- **Access token (30 min):** signed JWT, not looked up in the database, so it stays valid until it expires.
- **Refresh token (60 days):** random value; only its hash is stored in `sessions`.
- **Logout** = delete the cookies and set `s_revoked_at` and `s_revoked_reason` on the session row.
- **Revocation** = invalidating a session on the server early: logout, "sign out other devices", a new sign-in (old session), password change or reset, account deletion, stolen-token detection.
- **Gap:** a stolen access token works up to 30 min after revocation. Close it by putting the session id in the JWT and checking it against `sessions` on each request (one indexed lookup).

### 4.3 Scheduler and "TCP ack"
A TCP acknowledgement only proves the next machine received bytes; it says nothing about the inbox. With SMTP you know the server **accepted** the message; with Gmail you will not get delivered/bounced events. For sending exactly once (Flow 6 in the drawio):
- creating or editing an event writes 2 `reminder_jobs` rows (X, start);
- a scheduler ticks every 60 s and takes due jobs with `FOR UPDATE SKIP LOCKED`;
- it inserts one `email_outbox` row per recipient with a unique idempotency key such as `reminder:<event>:lead:<user>`, so a duplicate insert fails;
- a worker sends outbox rows by priority, choosing a Gmail account of the right purpose that is under its daily limit, and records which account sent it;
- after a restart anything still `pending` and overdue is picked up.

### 4.4 Email provider (replaces the Resend section)
Chosen: Gmail SMTP through Nodemailer on port 587, a pool of accounts by purpose, app passwords in a secret store (not in the database). See 3.2 for limits. Options if volume outgrows it: a paid Resend plan or Amazon SES, both of which need a verified domain, so they come after Option C above.

### 4.5 EC2 and HTTPS without a domain
- EC2 alone means you handle OS updates, Node, process manager (systemd or pm2), nginx, log rotation, backups of `.env`, and the deploy script. Elastic Beanstalk adds a load balancer by default, which costs money.
- CloudFront in front of both the React build and `/api/*` gives the browser one origin, so cookies work with `SameSite=Strict` and no CORS is needed.
- Security groups: EC2 inbound 80 from the CloudFront prefix list only (not 443, since the origin hop is HTTP), SSH 22 from your IPs only; RDS inbound 5432 from the EC2 security group only; RDS in a private subnet, no public access.

### 4.6 Mobile and touch
Right-click on a free calendar slot becomes long-press; tag hover text becomes tap; side menu becomes a drawer; the workspace member list collapses to a drawer; the note utility menu becomes a bottom toolbar; month view is the phone default. The app is responsive, not mobile-first.

### 4.7 Delete
Recovery per object type, 15 days default; see Trash above.

### 4.8 Prisma ORM: how it fits
**Approach: SQL first.** `schema.sql` is the source of truth. It is loaded as the first migration (`prisma/migrations/0001_init/migration.sql`), and `schema.prisma` is produced from the database with `prisma db pull`. Later changes are new migration folders created with `prisma migrate dev --create-only`, where you add any trigger, function or partial index by hand.

| In `schema.sql` | Prisma |
|---|---|
| PART 1: enums, tables, keys, plain indexes, defaults | modelled in `schema.prisma` (enums, `Bytes` for `_enc`, `Json` for jsonb, `@db.Timestamptz`, `@db.Inet`) |
| Inline CHECK constraints | invisible to Prisma, stay in the database; mirror in DTOs |
| PART 2: 3 partial unique indexes, 1 expression index | check after `db pull` (step 5); raw SQL in the migration |
| PART 2: functions and triggers (`stamp_purge_after`, `set_event_end`, note locks, session-revoke trigger, `pick_mail_account`) | never touched by Prisma; called with `$queryRaw` where needed |
| PART 3: seeds | run once from the migration; later changes by migration |

**Calls that must be raw SQL** (use the tagged template `$queryRaw` / `$executeRaw`, never `$queryRawUnsafe` with user input): `acquire_note_lock`, `take_over_note_lock`, invite redeem (the atomic UPDATE in `schema.sql`), `SELECT ... FOR UPDATE` on an event before counting subscribers, `FOR UPDATE SKIP LOCKED` on `reminder_jobs`, `pick_mail_account`.

**Habits**
- Rename models and fields to camelCase with `@map` / `@@map`; add `@updatedAt` to `w_updated_at`, `n_updated_at`, `ev_updated_at`.
- Session replacement: one `prisma.$transaction` that revokes the old session (reason `replaced_by_new_login`) and creates the new one; on error code `P2002` retry once.
- Optimistic note save: `updateMany({ where: { id, version } , data: { version: { increment: 1 } } })` and treat `count === 0` as a stale save.
- Columns filled by triggers (`ev_end_at`, `*_purge_after`) are returned by Prisma after create/update, so re-read nothing.
- Ids stay `String` (uuid) or `Int`; there is no `BigInt` anywhere.
- Set a small connection pool in `DATABASE_URL` (`connection_limit=[n]`) because the instance and database are tiny. If your Prisma version ships a native query engine, set the build target to match the EC2 operating system, and run `prisma generate` in CI so the generated client is inside the release bundle.
- Never accept a generated migration that drops or recreates one of the three partial unique indexes, a trigger or a CHECK. Read every migration before merging.

---

## 5. Scope versus a 2-month, 2-person timeline

| Priority                    | Items                                                                                                                                                                                                                                                                        |
| --------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Must (weeks 1-6)**        | Prisma baseline + CI migrations (week 0-1, estimate [P to confirm]), sign up / sign in / single session, email verification, forgot password OTP, workspaces, notes (encrypted, autosave), events + calendar, invites + subscribe, reminders by email, settings (theme, language, timezone, date format), error page, delete with confirm (soft delete) |
| **Should (weeks 6-7)**      | Trash page + restore + purge job, workspace sharing with read/write, note occupancy lock + owner take-over, predefined tags, note-event links, account deletion + restore, lockout + CAPTCHA, French                                                                                                                |
| **Could (week 8 or later)** | Arabic + right-to-left layout, accessibility toggles beyond the AA baseline, week start / numeric month, event colour polish                                                                                                                                                 |
| **Won't (v1)**              | SMS, Gmail pool beyond testing, copy-link invites, Google sign-in, websocket chat, meeting-app integration, Google Maps, recurring events, note history, custom domain                                                                                                                                                     |

Biggest schedule risks: encryption + S3 pipeline, scheduler correctness, time zones, trash/purge correctness, and two people covering frontend, backend and AWS.

---

## 6. Options

### 6.1 Backups and recovery
| Option          | What                                                                                                                                 | RPO / RTO                              | Cost        |
| --------------- | ------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------- | ----------- |
| A (recommended) | RDS automated backups, 7-day retention, point-in-time restore. **Notes bucket: versioning off** (or non-current versions expire after 1 day), see 3.2 | RPO about 5 min, RTO 30-60 min, manual | small       |
| B               | A + weekly `pg_dump` to another bucket                                                                                               | plus an independent copy               | pennies     |
| C               | A + Multi-AZ                                                                                                                         | RTO minutes                            | over budget |
Test a restore once. Keep a copy of `.env` and the encryption keys off the server; losing the key means losing every note. Trash purge and backups interact: a purged note can still exist in a backup for the retention period; say so in the privacy text.

### 6.2 Logging, monitoring, alerting
CloudWatch logs (14-day retention) and alarms for CPU, status check, API 5xx, RDS storage; free external uptime ping on `/health`; AWS Budgets alerts (section 1); Sentry free plan; a security log of sign-ins, failures, lockouts, resets, revocations and invite redemptions. Never log passwords, OTPs, tokens, decrypted personal data or note content. Add an alert when the outbox has more than N unsent rows or the daily email budget is nearly used.

### 6.3 Expected volume (fill in or accept)
| Assumption                                 | Proposed                                                                                   | Your value |
| ------------------------------------------ | ------------------------------------------------------------------------------------------ | ---------- |
| Users at launch / in 6 months              | 100 / 1,000                                                                                | 50/ 100    |
| Avg notes per user, avg size               | 50, 20 KB (limit 2 MB)                                                                     | 20, 10 KB  |
| Concurrent users at peak                   | 20                                                                                         | 10         |
| Events per user per month, avg subscribers | 10, 5 (max 1000)                                                                           | proposed   |
| Emails per day at launch                   | worst case 100 users x 1 event/day x 5 subs x 3 reminders = 1,500/day                     | 750/day (your figure; my estimate from your other numbers is about 200 reminders/day with 2 reminders) |
The servers cope with 1 GB of notes on one t3.micro and one db.t3.micro. **The Gmail daily limit is what breaks first.** If the instance dies, rebuild it from the artifacts bucket + `.env` backup; reminders resume from the database.

### 6.4 Email volume options (Q-24, informed by Gmail's 500/day). Your answer: options 1 and 2
1. Keep Gmail; priority queue + account pool with daily limits (built in); show organizers "reminders may be delayed for large events".
2. Reduce to two reminders (X and start). **Chosen, with option 1.**
3. Send reminders only to the first N subscribers (for example 100).
4. When a domain exists: move to Amazon SES or a paid Resend plan, no other code changes.

### 6.5 Rate limiting, validation, XSS, CI/CD, IaC
- `@nestjs/throttler` (in-memory is fine on one instance; limits reset on restart). Stricter on sign in, OTP, invite redeem, sign up, workspace add-by-email.
- `class-validator` DTOs with whitelist (mirroring the CHECK constraints); body size limits (2 MB for notes, small for everything else); Prisma Client parameterizes queries, raw SQL only through tagged templates.
- XSS: sanitize on display (DOMPurify), Content-Security-Policy, `helmet`. This matters more if notes are Markdown or HTML (C-3).
- CSRF: `SameSite=Strict` on a single origin plus a header check.
- CI/CD: GitHub Actions: pull request = lint + unit + module tests; merge = build, `prisma generate`, upload to the artifacts bucket; the deploy script on EC2 pulls it, runs `prisma migrate deploy`, restarts the API (RDS is private, so CI cannot run migrations itself). Your "pipeline of environments" fits this: Dev (local Docker), Test (CI with a throwaway Postgres), Staging (optional), Production.
- IaC: Terraform or AWS CDK: [team choice, Q-25]. It is the only open item that should be settled before week 1.

### 6.6 Rough monthly AWS cost (verify in the AWS pricing calculator)
| Item                                     | Rough monthly        |
| ---------------------------------------- | -------------------- |
| EC2 t3.micro                             | about $8             |
| RDS db.t3.micro + 20 GB                  | about $15 to $17     |
| Public IPv4 address                      | about $3.60          |
| S3, CloudFront, CloudWatch at this scale | under $3             |
| **Total**                                | **about $28 to $32** |
Without the domain and Route 53, the total is a little lower than in revision 2. At that rate $100 of credits lasts a bit over 3 months. These are list prices from memory, not checked today. Suspension is at 3 months (M10), so the real spend is about 3 x $28 to $32, inside the $100.

---

## 7. Detailed behaviors

- **Event times:** UTC `timestamptz` + the event's IANA timezone. Changing your own timezone does not move events. Reminder emails use the recipient's timezone and formats.
- **Reminders:** X before and at start; skip those already in the past; editing the start recalculates; delete or trash cancels; restore re-creates.
- **Concluded:** `now > start + duration`. Read-only, drawn in greyscale of the organizer's colour. In-progress events stay editable.
- **Subscribing:** one active subscription per user per event; re-subscribe allowed; organizer is implicit and not counted in the 999. Unverified users cannot subscribe.
- **Invites:** organizer enters an email, the invite is listed (pending / used / revoked), the invitee gets an email with the link. Email-bound and single-use: only the signed-in verified account with that email can redeem it. Valid until the event ends or 30 days, whichever is first; revocable; one pending invite per email per event. A visitor signs in first and returns to the link; a wrong account sees a message and the link stays valid.
- **Note occupancy (v1):** opening a note (edit or view) takes its lock (`acquire_note_lock`); a heartbeat every ~30 s renews it; no heartbeat for 2 min, leaving, or a revoked session frees it. Others see "in use by <handle/>" and a read-only view. The workspace owner can take over (`take_over_note_lock`); the displaced user is told and keeps a local draft.
- **Sign up:** phone is optional, stored encrypted, not used by any feature in v1.
- **Workspace access:** `read` can view; `write` can create and edit notes; only the owner deletes, manages members and tags. Added by exact email, must accept.
- **Notes:** title plaintext and searchable, content encrypted. Stale saves are rejected with a "Reload / Keep mine" choice.
- **Tags:** predefined only, not owned, no duplicates on one item, sorted A-Z.
- **Trash:** deleted items keep `deleted_at` and `purge_after`; the Trash page shows days left with Restore and Delete now; a nightly job removes S3 files, then rows, once `purge_after` has passed.
- **Errors:** pages show a specific message for connection or server problems, but never reveal whether an account or email exists.

---

## 8. Round 4 answers and where they were applied

| # | Your answer | Applied |
|---|---|---|
| M1 | Keep the phone field in the sign-up form | Optional, encrypted field kept; diagram v11, schema comment, template US-01 (section 10) |
| M2 | Default | 100 per account, 3 accounts to begin |
| M3 | Default | 20/day per organizer, 50 per event (step 36) |
| M4 | Lock per note; owner can take over; viewer occupies like an editor | `note_locks`, `acquire_note_lock`, `take_over_note_lock`; Website, Page States, Flows 9 and DB pages |
| M5 | Default | TipTap with Markdown, `==highlight==` |
| M6 | Default | Notes bucket versioning off |
| M7 | Default | Block sign up, allow sign in when reCAPTCHA fails |
| M8 | Default | README.md, TODO.md, NOTES.md regenerated |
| M9 | Default | 12 tags final |
| M10 | Suspend at 3 months | Section 1, step 49, risk R-18 (section 10) |
| Extra | Make `schema.sql` Prisma-compatible and adapt the plan | Schema rev 5, 4.8, steps 3 to 10 |

Still open (do not block week 1 except the first): Q-25 CI/CD and IaC tool [Terraform or AWS CDK], C-6 domain (design works with none), Q-26 decision log, Q-27 roles.

---

## 9. Final action steps

Owners follow the template: P = backend and AWS, J = frontend, database and testing, the other person reviews. Weeks are those of `PLAN_TEMPLATE.md` (week 1 = 9-15 Nov). Do the steps in order inside each phase.

**A. Repository, database and Prisma (week 0-1)**
1. [J] Create the repository Scribbl with folders `web/`, `api/`, `prisma/`, `infra/`, `docs/`; commit `PROJECT_PLAN.md`, `schema.sql`, `Scribbl.drawio`, `README.md`, `TODO.md`, `NOTES.md`.
2. [J] Add `docker-compose.yml` with PostgreSQL 16; on an empty database run `psql -v ON_ERROR_STOP=1 -f schema.sql` and confirm it exits with 0.
3. [P] In `api/` create the NestJS app; install `prisma` (dev) and `@prisma/client` at [Prisma version]; run `npx prisma init --datasource-provider postgresql`; put `DATABASE_URL` in `.env` (git-ignored).
4. [J] Copy `schema.sql` to `prisma/migrations/0001_init/migration.sql`; on an empty database run `npx prisma migrate deploy`, then `npx prisma db pull` to create `prisma/schema.prisma`.
5. [J] In `schema.prisma` check that `one_active_session_per_user`, `one_active_subscription` and `one_pending_invite_per_email` have their `where` condition. If a line shows them without it, delete that line (the database keeps the index) and write it in `NOTES.md`.
6. [J] Rename models and fields to camelCase with `@map` and `@@map`; add `@updatedAt` to `w_updated_at`, `n_updated_at`, `ev_updated_at`; run `npx prisma validate` and `npx prisma generate`.
7. [J] On a throwaway database run `npx prisma migrate dev --name sync_check`. Expected: nothing to apply. If the generated SQL drops or recreates an index, trigger or CHECK, delete that migration and fix `schema.prisma`.
8. [P] Create `PrismaService` (extends `PrismaClient`, connects on module init) and set `connection_limit=[n]` in `DATABASE_URL`.
9. [P] Create `CryptoService` (AES-256-GCM, key version stored in front of each ciphertext, key read from [Parameter Store name]); use it for `us_first_name_enc`, `us_last_name_enc`, `us_phone_enc`, `us_birth_date_enc`, `us_address_enc` and for note files.
10. [P] Add the GitHub Actions pull-request job: PostgreSQL 16 service, `npx prisma migrate deploy`, lint, unit and module tests, and a check that `prisma migrate diff --from-migrations prisma/migrations --to-schema-datamodel prisma/schema.prisma --shadow-database-url [shadow db url] --exit-code` finds no difference (flag names vary by Prisma version; check `--help`).

**B. AWS, Gmail and CAPTCHA (week 0-1)**
11. [P] Create the AWS account; record [AWS account creation date] and [AWS account creation date + 3 months] in `NOTES.md` and in both teammates' calendars; create three budget alerts on gross usage ($25, $50, $80) and one $1 actual-charges alert.
12. [J] Create three dedicated Gmail accounts (security, reminder, invite) with 2-Step Verification; store each app password in [Secrets Manager or Parameter Store path]; insert three `mail_accounts` rows with `ma_daily_limit` 100.
13. [P] Create the three S3 buckets (web, artifacts, notes with versioning off), the CloudFront distribution (default name, secret origin header), EC2 (nginx, systemd service), RDS private, and the security groups exactly as on the Architecture page.
14. [P] Write the deploy script on EC2: pull the release bundle, run `npx prisma migrate deploy`, restart the API; run it once from CI to deploy a hello-world.
15. [P] Create the reCAPTCHA key with the `*.cloudfront.net` hostname; test one assessment; implement policy M7 (block sign up, allow sign in when unreachable).
16. [J] Send one test email through each Gmail account with Nodemailer on port 587 and check spam placement.

**C. Auth and settings (weeks 1-2)**
17. [P] Build sign up: phone optional, TOS version stored, duplicate email gives the neutral reply, argon2id hash in `us_password_hash`, PII through `CryptoService`.
18. [P] Build sign in: lockout counter (`us_failed_logins`, `us_locked_until` after 10), then one `prisma.$transaction` that revokes the old session (`replaced_by_new_login`) and creates the new one; retry once on `P2002`; the JWT carries `sid`; a guard loads the session row on every request.
19. [P] Build refresh with a 10-second grace for the previous token, logout, `/auth/logout-others`, and email verification and OTP flows with the 15 min, 3 attempts, 2 min resend, 20/h limits.
20. [J] Build the Sign in, Sign up (with phone field), error and "Signed out elsewhere" pages from the Website and Page States diagrams; add the i18n skeleton (en first, fr next).
21. [J] Build Profile and Settings pages (US-06, US-20) and the user-settings endpoints.

**D. Workspaces and notes (weeks 3-4)**
22. [P] Build workspace CRUD with the 999 cap counted inside the create transaction; soft delete sets `w_deleted_at` (the trigger fills `w_purge_after`).
23. [P] Build note CRUD: encrypt the `.md` file, write it to the notes bucket, store `n_s3_key` and `n_size_bytes`; reject files of 2 MB or more; the 9999 cap is counted inside the create transaction.
24. [P] Implement stale-save rejection with `updateMany({ where: { id, version } })`; return a conflict when `count` is 0.
25. [J] Build the Workspace and Note pages with the TipTap Markdown editor (`==highlight==`, sanitized with DOMPurify), autosave after 10 s idle, Save/Discard/Stay prompt and local draft recovery.
26. [J] Build tag add/remove from the 12 seeded tags (no duplicates, sorted A-Z) and the note search bar (prefix search uses `notes_name_idx`).

**E. Events, invites, reminders (weeks 5-6)**
27. [P] Build event CRUD: `ev_duration_min` up to 43200, timezone from user settings, tags; the trigger fills `ev_end_at`.
28. [J] Build the calendar (Day/Week/Month, overlap layout, multi-day bars, concluded events in greyscale).
29. [P] On event create or edit upsert two `reminder_jobs` rows (`lead`, `start`); on trash cancel them; on restore re-create them.
30. [P] Build the scheduler: every 60 s, in one transaction, `SELECT ... FROM reminder_jobs WHERE rj_status='pending' AND rj_fire_at <= now() FOR UPDATE SKIP LOCKED`; insert one `email_outbox` row per recipient with key `reminder:<event>:<kind>:<user>`.
31. [P] Build the outbox worker: take pending rows by `eo_priority`, call `pick_mail_account(eo_purpose)`, send with that account's app password, record `eo_mail_account_id`, `eo_sent_at`, `eo_provider_msg_id`; if the function returns NULL leave the row pending; on a hard Gmail refusal set `ma_exhausted_until`.
32. [P] Build invite creation: random 256-bit token, store its SHA-256 in `ei_token_hash`, `ei_invitee_email` lower-cased, `ei_expires_at` = least of event end and 30 days.
33. [P] Build invite redeem with the atomic UPDATE from `schema.sql` through `$queryRaw`, then the subscription insert in the same transaction after `SELECT ... FOR UPDATE` on the event and the 1000 cap check; a wrong account gets a message and the link stays valid.
34. [J] Build the Event page, Invite popup (no copy-link), Invite page and the subscribe/unsubscribe flow.
35. [P] Add the Nodemailer templates (verification, OTP, invite, reminder, event edited/cancelled) with `eo_priority` 1, 1, 3, 5, 3.
36. [P] Enforce the invite quota before insert: count rows in `event_invites` by `ei_created_by` over the last 24 h (limit 20) and by `ev_id` (limit 50); reply neutrally when over the limit.

**F. Sharing, trash, locks (week 7)**
37. [P] Build workspace sharing by exact email with accept step, `read`/`write` permissions and the neutral reply.
38. [P] Build note lock endpoints: `POST /notes/:id/lock` (acquire and heartbeat through `acquire_note_lock`), `DELETE /notes/:id/lock` (release), `POST /notes/:id/lock/take-over` (owner only, `take_over_note_lock`); return the holder's handle when busy.
39. [J] Build the note lock UI: heartbeat every 30 s, "In use by <handle/>" read-only banner, Take over button for the owner, and the "owner took over" state that keeps a local draft.
40. [P] Build the Trash endpoints and the restore rules; add "Delete now".
41. [P] Build the purge job: select rows past `*_purge_after`, delete the S3 objects first, then the rows; add a dry-run flag and log every delete.
42. [P] Build account deletion and restore (restore link valid for the account retention days) and link notes to events.
43. [J] Finish French strings and the lockout and CAPTCHA screens.

**G. Hardening and launch (week 8)**
44. [J] Write and run the tests listed in section 8 of `PLAN_TEMPLATE.md`, including: second login revokes the first at once, revoked JWT rejected, lock released on revoke, owner take-over, double invite redeem race, reminder restart test, purge dry run on a copy.
45. [P] Restore an RDS backup once and time it; write the rollback steps.
46. [J] Run the accessibility pass on sign in, calendar and note page; tick the "Docs / decision note updated" box for every merged feature.
47. [P] Set CloudWatch alarms (CPU, 5xx, RDS storage, outbox backlog, Gmail budget nearly used) and the `/health` uptime ping.
48. [J] Walk through the launch checklist in section 7 of `PLAN_TEMPLATE.md` and fix every unchecked item.

**H. Suspension (3 months)**
49. [P] At [AWS account creation date + 3 months] minus 14 days: take a final `pg_dump`, copy the notes bucket and the encryption-key backup to storage outside AWS, then stop EC2 and RDS and put a maintenance page on CloudFront. The free-plan account is closed when credits end, so do this before that date.
50. [J] Record the suspension in `NOTES.md` and keep the exported data and keys with [owner of the export].

---

## 10. Edits to apply by hand to `PLAN_TEMPLATE.md`

The template was not part of this delivery, so make these edits yourselves (they keep your owners and estimates):
1. US-01: replace "no phone field at sign-up (N-4)" with "phone optional, stored encrypted (M1)".
2. US-27 (blank row): "As a note user I see when a note is in use" | "Opening a note takes the lock; viewers occupy like editors; heartbeat 30 s, 2 min timeout; owner Take over; displaced user keeps a local draft; lock freed on session revoke" | S | [P to fill] | [owner] | todo.
3. US-25: add "Prisma baseline and `prisma migrate deploy` in the deploy script".
4. Milestones: week 0 add "Prisma baseline (steps 2 to 10)"; week 7 add "note locks (US-27)".
5. Risks: add R-17 "Prisma migration drops a partial index, trigger or CHECK" (impact high; mitigation: steps 5, 7, 10, read every migration) and R-18 "Free-plan account closes at credit end and data is lost" (impact high; mitigation: step 49).
6. Test plan: add a row "Note locks: unit = acquire/renew/expire; module = viewer blocks editor, owner take-over, revoke frees lock".
7. Decision log starters: D-012 becomes "note occupancy lock (per note, owner can take over)"; add D-013 Prisma ORM with SQL-first migrations; D-014 suspend at 3 months.

Sources: [Prisma: unsupported database features](https://www.prisma.io/docs/orm/prisma-migrate/workflows/unsupported-database-features), [Google Cloud: reCAPTCHA billing](https://docs.cloud.google.com/recaptcha/docs/billing-information), [AWS Builder Center: the $0 AWS account in 2026](https://builder.aws.com/content/3Kkt4kNiDSUnO3n6db2weSNubzE/the-dollar0-aws-account-in-2026-free-plan-credits-guardrails), [Gmail SMTP limits](https://serversmtp.com/limits-of-gmail-smtp-server/).
