# Scribbl Week

Write it, Schedule it, Done. Scribbl Week is a web app for **notes** and **events**: people keep notes in workspaces, schedule events, invite others by email, and subscribers get email reminders. A note can link to an event.

Status: final plan (revision 5), build starts now. Team: P and J. Deadline: about 3 Jan 2027. The product is suspended at 3 months of AWS usage counted from [AWS account creation date].

## Read these first

| File | What it is |
|---|---|
| `PROJECT_PLAN.md` | The plan: decisions, risks, 50 numbered action steps (section 9) |
| `schema.sql` | The PostgreSQL schema, also the first Prisma migration |
| `Scribbl.drawio` | Five diagrams: Architecture, DB, Website, Page States, Flows |
| `PLAN_TEMPLATE.md` | Stories, milestones, risks, definition of done, test plan, decision log |
| `NOTES.md` | Why each decision was made |
| `TODO.md` | What is left, in priority order |

## What it does (v1)

- Sign up, verify email, sign in (one active session per user: a new sign-in logs the old one out), password reset by OTP.
- Workspaces with notes. Notes are encrypted Markdown (`.md`) files in S3, under 2 MB. Share a workspace by exact email with `read` or `write` access.
- Opening a note occupies it (edit or view) until you leave; the workspace owner can take it over.
- Events up to 30 days, shown on a calendar, with predefined tags (12).
- Email-bound, single-use invite links; subscribers get 2 reminders (X before, and at start).
- Trash with a recovery period per object (15 days by default), then purge.
- Languages: English, French, Arabic (right-to-left is optional). Accessibility toggles.

## Stack

React.js (S3 + CloudFront) | NestJS REST API `/api/v1` with **Prisma ORM** (one EC2 instance, nginx) | PostgreSQL 16 on RDS (private) | 3 S3 buckets (web, artifacts, notes) | Gmail SMTP through Nodemailer | reCAPTCHA. No load balancer, no custom domain: the site uses the CloudFront `*.cloudfront.net` name. AWS free plan, budget $100.

## Repository layout (planned)

`web/` React app | `api/` NestJS app | `prisma/` `schema.prisma` and `migrations/` | `infra/` AWS setup and deploy script | `docs/` diagrams and plan

## Run it locally

1. Start PostgreSQL 16: `docker compose up -d db`.
2. Create the database from the schema: `psql -v ON_ERROR_STOP=1 -f schema.sql` (or `npx prisma migrate deploy` once `prisma/migrations/0001_init` exists).
3. In `api/`: copy `.env.example` to `.env`, set `DATABASE_URL`, the encryption key and Gmail test values, then `npm install`, `npx prisma generate`, `npm run start:dev`.
4. In `web/`: `npm install`, `npm run dev`.

## Rules every contributor follows

- Every pull request is reviewed by the other person and passes CI.
- `schema.sql` is the source of truth for the database. PART 1 (tables) is modelled by Prisma; PART 2 (partial unique indexes, triggers, functions) is raw SQL. Never merge a generated migration that drops an index, trigger or CHECK constraint.
- Never log passwords, OTPs, tokens, decrypted personal data or note content. Email and username are plaintext; names, phone, birth date, address and note files are encrypted.
- Never reveal whether an account or email exists (neutral replies).
- Secrets (app passwords, encryption key) live in [Secrets Manager or Parameter Store], never in the repository or the database.
- Raw SQL only through Prisma tagged templates (`$queryRaw`), never with string concatenation.
- Definition of done: see section 5 of `PLAN_TEMPLATE.md` (includes loading, empty and error states, and the decision note).

## Getting help

Questions about a decision: look in `NOTES.md`, then ask [team contact]. Weekly planning is 30 minutes; decisions go in the decision log.
