# TODO (priority order)

Step numbers refer to section 9 of `PROJECT_PLAN.md`. Owners: P = backend and AWS, J = frontend, database and testing.

## P0: before any feature work (week 0-1)
- [ ] Decide the IaC tool [Terraform or AWS CDK] (Q-25). Owner: P and J.
- [ ] Repository and local database (steps 1-2). J
- [ ] Prisma baseline, index check, sync check (steps 3-7). P, J. This is the first real test of the schema with Prisma.
- [ ] PrismaService, CryptoService, CI job with migration check (steps 8-10). P
- [ ] AWS account, budgets, suspension date written down (step 11). P
- [ ] Three Gmail accounts, app passwords, `mail_accounts` rows (step 12). J
- [ ] S3, CloudFront, EC2, RDS, deploy script, hello-world deployed (steps 13-14). P
- [ ] reCAPTCHA key and test email (steps 15-16). P, J

## P1: Must (weeks 1-6)
- [ ] Sign up, sign in with one active session, refresh, logout, verification, OTP (steps 17-19). P
- [ ] Auth, error and settings pages, i18n skeleton (steps 20-21). J
- [ ] Workspaces, encrypted notes, stale-save check (steps 22-24). P
- [ ] Editor, autosave, tags, search (steps 25-26). J
- [ ] Events, calendar (steps 27-28). P, J
- [ ] Reminder jobs, scheduler, outbox worker, templates (steps 29-31, 35). P
- [ ] Invites, redeem, quota, subscribe (steps 32-34, 36). P, J

## P2: Should (weeks 6-7)
- [ ] Workspace sharing (step 37). P
- [ ] Note locks and owner take-over (steps 38-39). P, J
- [ ] Trash, purge job with dry run, account deletion and restore, note-event links (steps 40-42). P
- [ ] French, lockout and CAPTCHA screens (step 43). J

## P3: Hardening and launch (week 8)
- [ ] Test plan, including lock, session, invite race, reminder restart, purge dry run (step 44). J
- [ ] Backup restore test and rollback steps (step 45). P
- [ ] Accessibility pass, docs ticks (step 46). J
- [ ] Alarms and uptime ping (step 47). P
- [ ] Launch checklist (step 48). J

## P4: Could (week 8 or later)
- [ ] Arabic right-to-left layout.
- [ ] Accessibility toggles beyond the AA baseline, week start, numeric month, event colour polish.

## Suspension (at [AWS account creation date + 3 months])
- [ ] Export data and keys outside AWS 14 days before, stop EC2 and RDS, maintenance page (steps 49-50). P, J

## Still open (do not block week 1)
- [ ] C-6 domain (design works with none), Q-26 decision log, Q-27 roles.
- [ ] Apply the seven edits to `PLAN_TEMPLATE.md` (section 10 of the plan). J
- [ ] Confirm estimates for the Prisma baseline and US-27 [P to fill].

## Not in v1
SMS, Google sign-in, websocket chat, meeting-app integration, Google Maps, recurring events, note history, custom domain, copy-link invites, Gmail pool beyond testing.
