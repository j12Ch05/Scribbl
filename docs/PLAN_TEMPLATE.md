# Scribbl Week: fill-in sheets

Pre-filled where the answers already gave enough. Cells marked `____` are yours to fill. Priorities are M (must), S (should), C (could) from section 5 of PROJECT_PLAN.md. Estimates are in ideal days (one person, focused).
P is team member 1 and J is team member 2

_Revision 4: updated for After_review_2 (one session, email-bound invites, 2 reminders, retention). Your owners, estimates and ticks are kept. Note: nothing was estimated for infrastructure or testing before; see plan section 3.2._

## 1. Team and ownership

| Area                                                                                                              | Owner | Reviewer |
| ----------------------------------------------------------------------------------------------------------------- | ----- | -------- |
| Frontend (React, i18n, calendar)                                                                                  | J     | P        |
| Backend (NestJS, auth, scheduler)                                                                                 | P     | J        |
| Database and migrations                                                                                           | J     | P        |
| AWS, CI/CD, IaC, budget alerts                                                                                    | P     | J        |
| Testing and QA                                                                                                    | J     | P        |
| Gmail SMTP account (2-Step Verification + app password), AWS root account, registrar (only if a domain is bought) | J     | P        |

Rules: every pull request is reviewed by the other person. Weekly 30-minute planning. Decisions go in section 9.

## 2. User stories and acceptance criteria (Q69-71)


| ID    | Story                                                   | Acceptance criteria (draft, edit)                                                                                                                                                                                                                                              | Pri | Est       | Owner | Status |
| ----- | ------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | --- | --------- | ----- | ------ |
| US-01 | As a visitor I can sign up                              | Form validates all fields; password rules enforced; TOS accepted and stored with version; CAPTCHA; duplicate email gives a neutral reply; PII (except email, username) stored encrypted; phone optional, stored encrypted (M1)                                                 | M   | 3 days    | J     | todo   |
| US-02 | As a user I can verify my email                         | Email link only (SMS cut); valid 15 min; reuse fails; re-request after 2 min cooldown; unverified users can sign in but cannot subscribe                                                                                                                                       | M   | 3 days    | J     | todo   |
| US-03 | As a user I can sign in                                 | Valid credentials set httpOnly cookies (30 min / 60 days); generic error that never says which part; network errors may be named; 10 failures lock 24 h; ONE active session: a new sign-in revokes the old one, reason stored (C-1, N-8); every request checks the session row | M   | 3 days    | J     | todo   |
| US-04 | As a user I can reset a forgotten password              | OTP 8 chars, 15 min, 3 tries, 2 min resend, 20 req/h per IP and email; same neutral reply for any email; all sessions revoked after reset                                                                                                                                      | M   | 3 days    | J     | todo   |
| US-05 | As a user I can sign out                                | Cookies cleared and this device's session revoked; refresh token rejected afterwards; "sign out other devices" in Profile                                                                                                                                                      | M   | 1 day     | P     | todo   |
| US-06 | As a user I can edit profile, change email/username     | Email change re-verified; username once per 7 days; handle shown to others                                                                                                                                                                                                     | S   | 2 days    | P     | todo   |
| US-07 | As a user I can delete and restore my account           | Password confirm; soft delete with owned workspaces and organized events; restore link 15 days; purge job; final email                                                                                                                                                         | S   | 2 days    | P     | todo   |
| US-08 | As a user I can create, rename and delete a workspace   | Max 999 per user; delete asks Confirm/Cancel and moves to Trash; notes and S3 files removed only at purge                                                                                                                                                                      | M   | 3 days    | J     | todo   |
| US-09 | As a user I can create, edit and delete notes           | Max 9999 live notes per workspace; file < 2 MB; encrypted in S3; format per C-3; title searchable; stale save rejected                                                                                                                                                         | M   | 3 days    | P     | todo   |
| US-10 | As a writer I get autosave                              | Saves 10 s after the last keystroke; "Saved / Not saved" status; Save/Discard/Stay prompt on leaving; local draft recovery (Q-16)                                                                                                                                              | M   | 2 days    | P     | todo   |
| US-11 | As an owner I can share a workspace                     | Owner enters the exact email (no search suggestions); neutral reply; invitee accepts, pending shown; read/write; remove; invitation and revocation emails                                                                                                                      | S   | 2 days    | J     | todo   |
| US-12 | As a user I can tag workspaces and events               | + opens popup with the predefined tag list; no duplicates on one item; x removes; sorted A-Z; description on hover/tap                                                                                                                                                         | S   | 1 day     | P     | todo   |
| US-13 | As a user I can create an event                         | Title, start, duration, location text, reminder X, colour, tags; timezone auto-filled from settings                                                                                                                                                                            | M   | 2 days    | J     | todo   |
| US-14 | As an organizer I can edit or delete my event           | Editable until concluded; Save button lights on change; unsaved prompt; subscribers emailed on edit and cancel; delete moves to Trash                                                                                                                                          | M   | 2 days    | J     | todo   |
| US-15 | As a user I can see events on a calendar                | Blocks sized by duration; overlaps share width; concluded events greyscale; Day/Week/Month; Today; right-click or long-press to create                                                                                                                                         | M   | 2 days    | J     | todo   |
| US-16 | As an organizer I can invite people                     | Organizer adds invitee emails to a list (pending / used / revoked); email-bound single-use link sent (no copy link); redeem needs the verified account with that email; valid until event end, max 30 days; hashed token; revoke; per-organizer daily invite limit             | M   | 2 days    | P     | todo   |
| US-17 | As an invitee I can subscribe                           | Not signed in goes to sign in and back; redeem atomic; full event (1000) shows a message; used/revoked/ended shows a message; unsubscribe and re-subscribe allowed                                                                                                             | M   | 2 days    | P     | todo   |
| US-18 | As a subscriber I get 2 reminders                       | X before and at start; in my timezone; never duplicated; sent by priority within the Gmail daily budget; retried on failure                                                                                                                                                    | M   | 2 days    | P     | todo   |
| US-19 | As a writer I can link a note to an event               | Link appears on both; visibility rule (Q-22)                                                                                                                                                                                                                                   | S   | 2 days    | J     | todo   |
| US-20 | As a user I can set my preferences                      | Theme, language (en/fr first), font, accent, date format, 24h, numeric month, week start, timezone; persists across sign-ins                                                                                                                                                   | M   | 2 days    | J     | todo   |
| US-21 | As a user I see helpful error pages                     | Template page with message + Home button; states per page as in the drawio "Page States"                                                                                                                                                                                       | M   | 1 day     | P     | todo   |
| US-22 | As an Arabic reader I get right-to-left layout          | Mirrored layout, Arabic strings                                                                                                                                                                                                                                                | C   | 2 day     | P     | todo   |
| US-23 | As a user with accessibility needs I can enable toggles | Spec from Q-17                                                                                                                                                                                                                                                                 | C   | 2 day     | P     | todo   |
| US-24 | As a user I can restore deleted items                   | Trash page lists deleted workspaces, notes, events with days left; Restore; Delete now; event restore re-creates reminders and emails subscribers; purge job at purge_after (retention per object, 15 days default) deletes S3 files first, then rows                          | S   | 2 day     | J     | todo   |
| US-25 | As the team we have a deployable stack                  | AWS stack (S3 x3, CloudFront with secret origin header, EC2, RDS, security groups, budgets incl. $1 actual-charges alert), CI/CD, deploy script, backups configured, Prisma baseline and `prisma migrate deploy` in the deploy script                                          | M   | 2 day     | P     | todo   |
| US-26 | As the team we can trust releases                       | Test setup in CI with throwaway Postgres; module tests per section 8; restore test; reminder restart test                                                                                                                                                                      | M   | Every day | J     | todo   |
| US-27 | As a note user I see when a note is in use              | Opening a note takes the lock; viewers occupy like editors; heartbeat 30 s, 2 min timeout; owner Take over; displaced user keeps a local draft; lock freed on session revoke                                                                                                   | S   | 1 day     | P     | todo   |

## 3. Milestones (8 weeks, edit)

| Week             | Goal                                                                                                                                                                                                                          | Exit check                                                                            |
| ---------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------- |
| 0 (4-8 Nov)      | AWS account + budgets (incl. $1 actual-charges alert), dedicated Gmail + app password, repo, CI skeleton, local Docker Postgres with `schema.sql`, CAPTCHA and CloudFront-to-EC2 header test, Prisma baseline (steps 2 to 10) | Hello-world deployed through CI to the real stack; a test email is sent through Gmail |
| 1 (9-15 Nov)     | Sign up, sign in, sessions, i18n skeleton, error page                                                                                                                                                                         | US-01, 03, 05, 21 pass                                                                |
| 2 (16-22 Nov)    | Verification, forgot password, profile, settings                                                                                                                                                                              | US-02, 04, 06, 20 pass                                                                |
| 3 (23-29 Nov)    | Workspaces, notes CRUD, encryption + S3 pipeline                                                                                                                                                                              | US-08, 09 pass, encrypted file verified in S3                                         |
| 4 (30 Nov-6 Dec) | Autosave, unsaved prompts, search, tags                                                                                                                                                                                       | US-10, 12 pass                                                                        |
| 5 (7-13 Dec)     | Events, calendar                                                                                                                                                                                                              | US-13, 14, 15 pass                                                                    |
| 6 (14-20 Dec)    | Invites by email, subscriptions, email outbox with priority + daily budget, reminders                                                                                                                                         | US-16, 17, 18 pass, restart test shows no lost or duplicate reminders                 |
| 7 (21-27 Dec)    | Workspace sharing, Trash + restore + purge, account deletion, note-event links, French, lockout + CAPTCHA, note locks (US-27)                                                                                                 | US-07, 11, 19, 24 pass                                                                |
| 8 (28 Dec-3 Jan) | Hardening: security review, backup restore test, load test, accessibility pass, docs, launch checklist                                                                                                                        | All "Must" done; section 7 checklist green                                            |

Weeks 7 and 8 fall over the year-end holidays; if they apply to you, plan for less capacity.

Buffer: nothing. If a week slips, move a "Should" to "Could" rather than extending the deadline. Decide this on day 1 of each week.

## 4. Risk register

| ID   | Risk                                                                      | Likelihood | Impact | Mitigation                                                                                                                          | Owner |
| ---- | ------------------------------------------------------------------------- | ---------- | ------ | ----------------------------------------------------------------------------------------------------------------------------------- | ----- |
| R-1  | Two developers cannot deliver all "Must" items in 8 weeks                 | ___        | high   | Triage in plan section 5; weekly re-plan; cut Could/Should first                                                                    | ___   |
| R-2  | Reminder sent twice, late or never                                        | ___        | high   | DB jobs + outbox with idempotency key; restart test; alarms on stuck jobs                                                           | ___   |
| R-3  | Time zone / DST bugs                                                      | ___        | medium | UTC storage, IANA zones, library (date-fns-tz or Luxon), test around DST changes                                                    | ___   |
| R-4  | Encryption keys stored in `.env` on the same server                       | ___        | high   | Back up keys off-server; move to Parameter Store; key version column for rotation; document loss = notes unreadable                 | ___   |
| R-5  | Credits run out before launch (about 3 months at current estimate)        | ___        | medium | Budget alerts on gross usage; stop unused resources; secure sponsorship early                                                       | ___   |
| R-6  | Gmail limit (about 500 recipients/day) exceeded, or Google blocks SMTP    | ___        | high   | Priority outbox with daily budget; dedicated account; decide N-1; move to SES/Resend when a domain exists                           | ___   |
| R-7  | Single instance down                                                      | ___        | medium | Recreate from artifacts bucket; uptime alert; reminders resume from DB                                                              | ___   |
| R-8  | Lost update on shared notes                                               | ___        | medium | `n_version` check and conflict dialog                                                                                               | ___   |
| R-9  | Account takeover through weak recovery                                    | ___        | high   | OTP required; birth date/address only as extra factor                                                                               | ___   |
| R-10 | Arabic RTL consumes more time than planned                                | ___        | low    | Keep as "Could" until French is done                                                                                                | ___   |
| R-11 | Dedicated Gmail account suspended or app password lost                    | ___        | high   | 2-Step Verification, recovery contact, password in `.env` backup                                                                    | ___   |
| R-12 | CloudFront to EC2 hop is plain HTTP (no domain)                           | ___        | medium | Security group = CloudFront prefix list only; secret header required by nginx; no secrets in URLs; move to Option B/C when possible | ___   |
| R-13 | Year-end holidays reduce weeks 7-8                                        | ___        | medium | Finish Must items by week 6; keep Should items cuttable                                                                             | ___   |
| R-14 | Purge job deletes live data or leaves S3 orphans                          | ___        | high   | Purge only rows past purge_after (retention_policy); dry-run mode; test on a copy; log every delete                                 | ___   |
| R-15 | Two tabs/devices refreshing at once trigger false token-replay revocation | ___        | medium | 10 s grace for the previous refresh token; test concurrent refresh                                                                  | ___   |
| R-16 | Emailed links break if the CloudFront distribution is recreated           | ___        | medium | Never delete the distribution; template links from one config value                                                                 | ___   |
| R-17 | Prisma migration drops a partial index, trigger or CHECK                  | ___        | high   | steps 5, 7, 10, read every migration                                                                                                | ___   |
| R-18 | Free-plan account closes at credit end and data is lost                   | ___        | high   | step 49                                                                                                                             | ___   |

## 5. Definition of done (per feature)

Two boxes are unchecked (loading/empty/error states, docs/decision note). If that is deliberate, say so in N-6 of the plan; otherwise tick them.

- [X] Acceptance criteria demonstrated
- [X] Unit tests for the module; module test across API + DB
- [X] Input validated; permission checks tested (owner, writer, reader, stranger)
- [X] Loading, empty and error states implemented (see "Page States")
- [X] Strings in i18n files (no hard-coded text)
- [X] No secrets or personal data in logs
- [X] Migration included; runs forward on a copy of production schema
- [X] Reviewed by the other developer; merged through CI green
- [ ] Docs / decision note updated

## 6. API outline (v1; mark each when the contract is written)

| Area       | Endpoints                                                                                                                                                                                                   | Done |
| ---------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---- |
| Auth       | POST `/auth/signup`, `/auth/verify`, `/auth/verify/resend`, `/auth/login`, `/auth/refresh`, `/auth/logout`, `/auth/logout-others`, `/auth/forgot`, `/auth/forgot/verify`, `/auth/reset` | [ ]  |
| Account    | GET/PATCH `/me`, PATCH `/me/email`, DELETE `/me`, POST `/me/restore`, GET `/me/sessions`, DELETE `/me/sessions/:id`                                                                             | [ ]  |
| Settings   | GET/PUT `/me/settings`, GET `/themes`, GET `/languages`                                                                                                                                               | [ ]  |
| Workspaces | GET/POST `/workspaces`, GET/PATCH/DELETE `/workspaces/:id`, POST `/workspaces/:id/members` (email), POST `/workspaces/:id/members/accept`, PUT/DELETE `/workspaces/:id/members/:userId`           | [ ]  |
| Notes      | GET/POST `/workspaces/:id/notes`, GET/PUT/DELETE `/notes/:id`, GET `/workspaces/:id/notes?q=`                                                                                                         | [ ]  |
| Tags       | GET `/tags`, PUT/DELETE `/workspaces/:id/tags/:tagId`, PUT/DELETE `/events/:id/tags/:tagId`                                                                                                           | [ ]  |
| Events     | GET/POST `/events`, GET `/events?from=&to=`, GET/PATCH/DELETE `/events/:id`, PUT/DELETE `/notes/:id/events/:eventId`                                                                                | [ ]  |
| Invites    | POST/GET `/events/:id/invites` (body: optional email), DELETE `/events/:id/invites/:inviteId`, POST `/invites/redeem`, DELETE `/events/:id/subscription`                                            | [ ]  |
| Trash      | GET `/trash`, POST `/trash/:type/:id/restore`, DELETE `/trash/:type/:id` (delete now)                                                                                                                 | [ ]  |
| Ops        | GET `/health` (no webhooks: Gmail SMTP has none)                                                                                                                                                          | [ ]  |

Write an OpenAPI file from NestJS decorators; commit the generated JSON so frontend and backend agree. Errors use one shape: `{ code, message }`.

## 7. Launch checklist

- [ ] CloudFront distribution (HTTPS), behaviors, security headers, secret origin header checked by nginx
- [ ] Gmail: 2-Step Verification on, app password in `.env`, test mail reaches Gmail and Outlook inboxes (check spam), daily budget counter tested
- [ ] RDS private, backups on, restore tested once
- [ ] Security groups match the Architecture page
- [ ] `.env` backed up off-server; key rotation procedure written
- [ ] Budgets and CloudWatch alarms confirm by email
- [ ] CAPTCHA keys and rate limits set to production values
- [ ] Reminder restart test passed (stop API mid-run, no loss, no duplicates)
- [ ] Accessibility pass on sign-in, calendar, note page
- [ ] Privacy text and TOS published; TOS version recorded
- [ ] Purge job tested on a copy: no live rows removed, S3 objects removed
- [ ] Rollback steps written

## 8. Test plan (Q69)

| Module                         | Unit tests                                                           | Module / integration tests                                               | Owner | Done |
| ------------------------------ | -------------------------------------------------------------------- | ------------------------------------------------------------------------ | ----- | ---- |
| Auth + sessions                | hashing, token expiry, lockout counter, OTP limits                   | full sign-up to sign-out, one-active-session rule, refresh rotation      | J     | [ ]  |
| Notes + encryption             | encrypt/decrypt round trip, key version, size limit                  | create, save, stale save, S3 object is ciphertext                        | P     | [ ]  |
| Workspaces + permissions       | permission matrix                                                    | owner, writer, reader, stranger against every endpoint                   | P     | [ ]  |
| Events + calendar              | duration/end maths, overlap layout, DST                              | create, edit concluded (rejected), delete notifies                       | J     | [ ]  |
| Invites + subscriptions        | token hash, expiry formula                                           | double redeem race, 1000 cap, resubscribe                                | P     | [ ]  |
| Reminders + outbox             | job creation, offsets                                                | restart test, duplicate insert, provider failure                         | P     | [ ]  |
| Trash + purge                  | retention_policy date maths, restore rules                           | restore event re-creates reminders; purge removes rows + S3              | J     | [ ]  |
| Sessions (one active)          | unique index, revoke reason, grace period for previous refresh token | second login revokes first at once; revoked JWT rejected; locks released | P     | [ ]  |
| i18n + settings                | formatters (date, time, week start)                                  | settings persist across sign-ins                                         | J     | [ ]  |
| End to end (optional, if time) |                                                                      | sign up, create note, create event, invite, subscribe                    | J     | [ ]  |
| Note locks                     | acquire/renew/expire                                                 | viewer blocks editor, owner take-over, revoke frees lock                 | J     | [ ]  |

## 9. Decision log (copy one block per decision)

```
ID: D-001
Date: ____
Decision: ____
Why / alternatives considered: ____
Consequences: ____
Decided by: ____
```

Starter entries to write down now: 
D-001 PostgreSQL; 
D-002 CloudFront single origin (default name);
D-003 DB-backed reminder scheduler; 
D-004 argon2id; 
D-005 server-side field encryption (email and username plaintext); 
D-006 UUID ids; 
D-007 one active session per user, newest sign-in wins; 
D-008 Gmail account pool (security / reminder / invite) with priority outbox, v1 only; 
D-009 trash with per-object retention, 15 days default; 
D-010 CloudFront default domain, no custom domain;
D-011 email-bound single-use invites; 
D-012 note occupancy lock (per note, owner can take over);
D-013 Prisma ORM with SQL-first migrations;
D-014 suspend at 3 months;