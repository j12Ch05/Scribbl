-- Scribbl Week: PostgreSQL schema, revision 5 (target: PostgreSQL 16 on RDS; works with Prisma ORM)
--
-- HOW THIS FILE IS ORGANISED (so it works as plain SQL AND with Prisma)
--   PART 1  enums, tables, plain indexes        -> everything Prisma can model. `prisma db pull` turns this into schema.prisma.
--   PART 2  database extras Prisma does not model: partial unique indexes, expression index, functions, triggers.
--           Prisma never drops or alters triggers/functions. They live in the migration SQL (see PROJECT_PLAN.md, section 4.8).
--   PART 3  seed data.
-- Load as is with:  psql -v ON_ERROR_STOP=1 -f schema.sql      (it is also prisma/migrations/0001_init/migration.sql)
--
-- Conventions
--   * UUID primary keys (gen_random_uuid, built in since PG13) for anything exposed in URLs.
--   * smallint / integer ids for tiny lookup tables. No bigint ids (Prisma returns BigInt, which JSON cannot serialise).
--   * All instants are timestamptz (stored as UTC). Time zones are IANA names (text).
--   * "_enc" columns hold application-encrypted bytes (AES-256-GCM: nonce || ciphertext || tag). Prisma type: Bytes (Node Buffer).
--   * Column prefixes follow the original ER diagram (u_, us_, w_, n_, ev_, tg_ ...). In schema.prisma map them to camelCase with @map.
--   * Inline CHECK constraints stay in the SQL: Prisma ignores them, so mirror each one in the NestJS DTO validation too.
--   * Columns filled by a trigger (ev_end_at, *_purge_after) have a harmless DEFAULT so the Prisma Client does not demand a value.
-- Revision history
--   3: trash, plaintext email, tags predefined, Gmail SMTP.   4: one active session, email-bound invites, retention policy,
--   Gmail pool, 30-day events, .md only.   5: Prisma-compatible layout; occupancy lock moved from workspace to NOTE (M4);
--   phone field kept at sign-up (M1); tag name is a plain unique column (no generated column).

-- ================================================================ PART 1: enums, tables, plain indexes
CREATE TYPE date_format        AS ENUM ('DMY', 'MDY', 'YMD');
CREATE TYPE workspace_perm     AS ENUM ('read', 'write');
CREATE TYPE challenge_purpose  AS ENUM ('password_reset', 'email_verify', 'email_change', 'account_restore');  -- SMS cut from v1
CREATE TYPE reminder_kind      AS ENUM ('lead', 'start');              -- X before start, and at start
CREATE TYPE mail_purpose       AS ENUM ('security', 'reminder', 'invite');  -- which Gmail pool sends it
CREATE TYPE revoke_reason      AS ENUM ('signed_out', 'replaced_by_new_login', 'expired', 'password_changed', 'account_deleted', 'locked');
CREATE TYPE job_status         AS ENUM ('pending', 'processing', 'done', 'failed', 'cancelled');
CREATE TYPE outbox_status      AS ENUM ('pending', 'processing', 'sent', 'failed', 'cancelled');

-- ---------------------------------------------------------------- lookup tables
CREATE TABLE theme_types (
    tt_id          smallint PRIMARY KEY,
    tt_name        text  NOT NULL UNIQUE,
    tt_colors      jsonb NOT NULL,                  -- e.g. {"bg":"#fff","fg":"#111","accent":"#6a00ff"}
    tt_description text
);

CREATE TABLE language_types (
    lt_id           smallint PRIMARY KEY,
    lt_code         text    NOT NULL UNIQUE,         -- 'en', 'fr', 'ar'  (BCP-47)
    lt_name         text    NOT NULL,
    lt_is_rtl       boolean NOT NULL DEFAULT false,  -- Arabic needs right-to-left layout
    lt_description  text
);

-- Recovery period per major object, editable by the team; 15 days by default. The value in force at deletion time is stamped on the row.
CREATE TABLE retention_policy (
    rp_object text PRIMARY KEY CHECK (rp_object IN ('account', 'workspace', 'note', 'event')),
    rp_days   integer NOT NULL DEFAULT 15 CHECK (rp_days BETWEEN 0 AND 365)
);

-- ---------------------------------------------------------------- users
CREATE TABLE users (
    u_id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    us_username          text NOT NULL,                       -- the "handle"; NOT unique, shown to others
    us_username_changed_at timestamptz,                       -- enforce "once every 7 days"
    -- per-field encrypted PII (email and username stay plaintext)
    us_first_name_enc    bytea NOT NULL,
    us_last_name_enc     bytea NOT NULL,
    us_email             text  NOT NULL CHECK (us_email = lower(us_email)),  -- NOT encrypted; used to sign in
    us_phone_enc         bytea,                               -- optional field on the sign-up form (M1); no feature uses it in v1
    us_birth_date_enc    bytea NOT NULL,
    us_address_enc       bytea,
    -- credentials: ONE column. argon2id/bcrypt encoded strings already contain salt + parameters.
    us_password_hash     text NOT NULL,
    -- verification, legal, abuse protection
    us_email_verified_at timestamptz,
    us_tos_version       text        NOT NULL,
    us_tos_accepted_at   timestamptz NOT NULL,
    us_failed_logins     smallint    NOT NULL DEFAULT 0,
    us_locked_until      timestamptz,                         -- 24 h after 10 failures
    -- lifecycle
    us_created_at        timestamptz NOT NULL DEFAULT now(),
    us_deleted_at        timestamptz,                         -- soft delete; restorable until us_purge_after
    us_purge_after       timestamptz,                         -- stamped by trigger from retention_policy at deletion time
    CONSTRAINT us_username_len CHECK (char_length(us_username) BETWEEN 1 AND 50)
);
CREATE UNIQUE INDEX users_email_uq ON users (us_email);
CREATE INDEX users_purge_idx ON users (us_purge_after);        -- nightly purge: WHERE us_purge_after < now()

CREATE TABLE user_settings (
    u_id             uuid PRIMARY KEY REFERENCES users ON DELETE CASCADE,
    tt_id            smallint    NOT NULL REFERENCES theme_types,
    lt_id            smallint    NOT NULL REFERENCES language_types,
    us_font          text        NOT NULL DEFAULT 'system',
    us_accent_color  text        NOT NULL DEFAULT '#6a00ff' CHECK (us_accent_color ~ '^#[0-9a-fA-F]{6}$'),
    us_time_24h      boolean     NOT NULL DEFAULT true,
    us_date_format   date_format NOT NULL DEFAULT 'DMY',
    us_month_numeric boolean     NOT NULL DEFAULT false,      -- show 03 instead of "March"
    us_week_start    smallint    NOT NULL DEFAULT 1 CHECK (us_week_start BETWEEN 0 AND 6),  -- 0 = Sunday
    us_timezone      text        NOT NULL DEFAULT 'UTC',      -- IANA name, validated in the API
    us_high_contrast boolean     NOT NULL DEFAULT false,      -- accessibility toggles (AA baseline for everyone)
    us_large_text    boolean     NOT NULL DEFAULT false,
    us_reduced_motion boolean    NOT NULL DEFAULT false
);

-- ---------------------------------------------------------------- sessions + auth challenges
-- ONE active session per user (C-1, N-8): a new sign-in revokes the previous session (reason 'replaced_by_new_login').
-- The API does it in ONE transaction: UPDATE old SET s_revoked_at..., then INSERT the new row. The partial unique index in PART 2
-- makes two active sessions impossible even under a race (the loser gets a unique violation, Prisma code P2002, and retries).
-- The JWT carries s_id and EVERY request checks the row is still active, otherwise a revoked login would stay valid until the
-- 30-minute access token expires.
CREATE TABLE sessions (
    s_id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    u_id             uuid        NOT NULL REFERENCES users ON DELETE CASCADE,
    s_refresh_hash   bytea       NOT NULL UNIQUE,               -- SHA-256 of the refresh token
    s_created_at     timestamptz NOT NULL DEFAULT now(),
    s_last_used_at   timestamptz NOT NULL DEFAULT now(),
    s_expires_at     timestamptz NOT NULL,                      -- created + 60 days
    s_revoked_at     timestamptz,
    s_revoked_reason revoke_reason,
    s_user_agent     text,
    s_ip             inet,
    CONSTRAINT revoked_has_reason CHECK ((s_revoked_at IS NULL) = (s_revoked_reason IS NULL))
);
CREATE INDEX sessions_user_idx ON sessions (u_id);

-- OTP codes and verification links (hashed; never store the raw code/token)
CREATE TABLE auth_challenges (
    ac_id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    u_id              uuid NOT NULL REFERENCES users ON DELETE CASCADE,
    ac_purpose        challenge_purpose NOT NULL,
    ac_code_hash      bytea       NOT NULL,                   -- 8-char OTP or link token, hashed
    ac_pending_value  text,                                   -- e.g. the NEW email during email_change
    ac_created_at     timestamptz NOT NULL DEFAULT now(),     -- resend cooldown (2 min) reads this
    ac_expires_at     timestamptz NOT NULL,                   -- created + 15 min (restore: + retention days)
    ac_attempts       smallint    NOT NULL DEFAULT 0 CHECK (ac_attempts <= 3),
    ac_consumed_at    timestamptz
);
CREATE INDEX auth_challenges_lookup ON auth_challenges (u_id, ac_purpose, ac_created_at DESC);

-- ---------------------------------------------------------------- workspaces + notes
CREATE TABLE workspaces (
    w_id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    u_id         uuid        NOT NULL REFERENCES users,       -- owner (absolute rights)
    w_name       text        NOT NULL CHECK (char_length(w_name) BETWEEN 1 AND 100),
    w_created_at timestamptz NOT NULL DEFAULT now(),
    w_updated_at timestamptz NOT NULL DEFAULT now(),          -- Prisma: @updatedAt
    w_deleted_at timestamptz,                                 -- trash: hidden now, purged at w_purge_after
    w_purge_after timestamptz                                 -- stamped from retention_policy
);
CREATE INDEX workspaces_owner_idx ON workspaces (u_id);
CREATE INDEX workspaces_trash_idx ON workspaces (w_purge_after);

-- Everyone except the owner. Owner is implicit via workspaces.u_id.
CREATE TABLE workspace_members (
    w_id          uuid NOT NULL REFERENCES workspaces ON DELETE CASCADE,
    u_id          uuid NOT NULL REFERENCES users      ON DELETE CASCADE,
    wm_permission workspace_perm NOT NULL DEFAULT 'read',
    wm_granted_at timestamptz    NOT NULL DEFAULT now(),         -- when the owner added the person
    wm_accepted_at timestamptz,                                  -- NULL = invitation still pending
    PRIMARY KEY (w_id, u_id)
);
CREATE INDEX workspace_members_user_idx ON workspace_members (u_id);

CREATE TABLE notes (
    n_id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    w_id            uuid        NOT NULL REFERENCES workspaces ON DELETE CASCADE,
    n_name          text        NOT NULL CHECK (char_length(n_name) BETWEEN 1 AND 200), -- plaintext, searchable
    n_s3_key        text        NOT NULL UNIQUE,              -- encrypted Markdown (.md) object in the notes bucket
    n_size_bytes    integer     NOT NULL DEFAULT 0 CHECK (n_size_bytes BETWEEN 0 AND 2097152),  -- < 2 MB
    n_version       integer     NOT NULL DEFAULT 1,           -- optimistic concurrency (reject stale saves)
    n_last_editor   uuid        REFERENCES users ON DELETE SET NULL,
    n_created_at    timestamptz NOT NULL DEFAULT now(),
    n_updated_at    timestamptz NOT NULL DEFAULT now(),       -- Prisma: @updatedAt
    n_deleted_at    timestamptz,                              -- trash: S3 object kept until n_purge_after
    n_purge_after   timestamptz
);
CREATE INDEX notes_workspace_idx ON notes (w_id);
CREATE INDEX notes_trash_idx     ON notes (n_purge_after);
-- Purge job order (important): 1) delete the S3 object(s), 2) only then delete the row. Deleting the row first orphans an
-- encrypted file nobody can find. Keep S3 versioning OFF on the notes bucket (M6), otherwise "purged" notes would still exist.
-- "no more than 9999 live notes per workspace" and "999 workspaces per user" are enforced in the API inside the create transaction
-- (a CHECK cannot count rows). Trashed rows do not count.

-- ---------------------------------------------------------------- note occupancy lock (M4, v1)
-- Locking is per NOTE, not per workspace. Opening a note (to edit OR just view) occupies it until the user leaves; a viewer
-- occupies it exactly like an editor. Others see "in use by <handle>". The workspace owner can take over a note that someone else
-- is using (take_over_note_lock in PART 2); the displaced user's next heartbeat fails and the UI tells them.
-- A heartbeat every ~30 s keeps the lock alive; 2 minutes of silence (closed tab, lost network) frees it. It is also released when
-- the holder's session is revoked (trigger in PART 2), so "latest login wins" cannot leave a lock stuck behind a logged-out device.
CREATE TABLE note_locks (
    n_id            uuid PRIMARY KEY REFERENCES notes ON DELETE CASCADE,        -- PK = at most one holder per note
    u_id            uuid        NOT NULL REFERENCES users    ON DELETE CASCADE,
    s_id            uuid        NOT NULL REFERENCES sessions ON DELETE CASCADE,
    nl_acquired_at  timestamptz NOT NULL DEFAULT now(),
    nl_heartbeat_at timestamptz NOT NULL DEFAULT now(),
    nl_expires_at   timestamptz NOT NULL
);
CREATE INDEX note_locks_user_idx    ON note_locks (u_id);
CREATE INDEX note_locks_session_idx ON note_locks (s_id);

-- ---------------------------------------------------------------- events
CREATE TABLE events (
    ev_id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    u_id               uuid        NOT NULL REFERENCES users,      -- organizer
    ev_title           text        NOT NULL CHECK (char_length(ev_title) BETWEEN 1 AND 150),
    ev_start_at        timestamptz NOT NULL,                       -- date + time in one instant
    ev_duration_min    integer     NOT NULL CHECK (ev_duration_min BETWEEN 1 AND 43200), -- up to 30 days (N-7)
    ev_end_at          timestamptz NOT NULL DEFAULT now(),         -- always overwritten by the trigger in PART 2 (default only keeps Prisma's create type optional)
    ev_timezone        text        NOT NULL,                       -- IANA, auto-filled from organizer's settings
    ev_reminder_min    integer     NOT NULL DEFAULT 60 CHECK (ev_reminder_min >= 0),   -- "X"
    ev_location        text,                                       -- free text in v1
    ev_description     text,
    ev_color           text        NOT NULL DEFAULT '#6a00ff' CHECK (ev_color ~ '^#[0-9a-fA-F]{6}$'),
    ev_max_subscribers integer     NOT NULL DEFAULT 999 CHECK (ev_max_subscribers BETWEEN 1 AND 999),
    ev_created_at      timestamptz NOT NULL DEFAULT now(),
    ev_updated_at      timestamptz NOT NULL DEFAULT now(),         -- Prisma: @updatedAt
    ev_deleted_at      timestamptz,                                -- trash: reminders cancelled, purged at ev_purge_after
    ev_purge_after     timestamptz
);
CREATE INDEX events_organizer_idx ON events (u_id, ev_start_at);
CREATE INDEX events_range_idx     ON events (ev_start_at, ev_end_at);
CREATE INDEX events_trash_idx     ON events (ev_purge_after);

-- The organizer is an implicit subscriber and is NOT stored here.
-- A user may re-subscribe after unsubscribing, so history rows are kept and only ONE active row may exist (index in PART 2).
CREATE TABLE event_subscriptions (
    es_id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    ev_id              uuid        NOT NULL REFERENCES events ON DELETE CASCADE,
    u_id               uuid        NOT NULL REFERENCES users  ON DELETE CASCADE,
    es_subscribed_at   timestamptz NOT NULL DEFAULT now(),
    es_unsubscribed_at timestamptz
);
CREATE INDEX event_subscriptions_event_idx ON event_subscriptions (ev_id);
CREATE INDEX event_subscriptions_user_idx  ON event_subscriptions (u_id);
-- Capacity (999 + organizer): the API locks the event row (SELECT ... FOR UPDATE), counts active rows, then inserts.

-- Invites are EMAIL-BOUND and SINGLE-USE (C-5, N-2): the link only works for the signed-in user whose VERIFIED email equals
-- ei_invitee_email, and only once. Valid until the event ends, never more than 30 days.
CREATE TABLE event_invites (
    ei_id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    ev_id          uuid        NOT NULL REFERENCES events ON DELETE CASCADE,
    ei_created_by  uuid        NOT NULL REFERENCES users,
    ei_token_hash  bytea       NOT NULL UNIQUE,                    -- SHA-256 of a 256-bit random token
    ei_invitee_email text      NOT NULL CHECK (ei_invitee_email = lower(ei_invitee_email)),
    ei_created_at  timestamptz NOT NULL DEFAULT now(),
    ei_expires_at  timestamptz NOT NULL,                           -- LEAST(event end, created + 30 d), set by the API
    ei_used_at     timestamptz,
    ei_used_by     uuid        REFERENCES users ON DELETE SET NULL,
    ei_revoked_at  timestamptz,                                    -- organizer cancelled the invite
    CONSTRAINT invite_max_30_days CHECK (ei_expires_at <= ei_created_at + interval '30 days')
);
CREATE INDEX event_invites_event_idx   ON event_invites (ev_id);
CREATE INDEX event_invites_creator_day ON event_invites (ei_created_by, ei_created_at);   -- per-organizer quota: 20/day, 50/event (M3)
-- Redeem atomically ($1 = signed-in user id, $2 = token hash, $3 = that user's VERIFIED email, from users.us_email with
-- us_email_verified_at IS NOT NULL). A wrong account matches 0 rows and the token is NOT burned. Run it with prisma.$queryRaw:
--   UPDATE event_invites i SET ei_used_at = now(), ei_used_by = $1
--     FROM events e
--    WHERE i.ev_id = e.ev_id AND i.ei_token_hash = $2 AND i.ei_invitee_email = $3
--      AND i.ei_used_at IS NULL AND i.ei_revoked_at IS NULL
--      AND i.ei_expires_at > now() AND e.ev_end_at > now() AND e.ev_deleted_at IS NULL
--   RETURNING i.ev_id;
-- then insert the event_subscriptions row in the same transaction (capacity check as above).

-- ---------------------------------------------------------------- tags (jsonb, not owned by anyone)
-- Users can only pick from this predefined list (team decision); add tags with a migration.
-- A workspace or event cannot hold the same tag twice: the join-table primary keys enforce it.
-- tg_name is a plain unique column (a generated column is invisible to Prisma); the CHECK keeps it equal to tg_data->>'name'.
CREATE TABLE tags (
    tg_id   integer GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    tg_name text    NOT NULL UNIQUE,
    tg_data jsonb   NOT NULL,                                      -- {"name","color","description"}
    CONSTRAINT tg_shape CHECK (
        jsonb_typeof(tg_data) = 'object'
        AND tg_data ? 'name' AND tg_data ? 'color' AND tg_data ? 'description'
        AND tg_data ->> 'color' ~ '^#[0-9a-fA-F]{6}$'
        AND tg_data ->> 'name' = tg_name
    )
);
CREATE INDEX tags_data_gin ON tags USING gin (tg_data);

CREATE TABLE workspace_tags (
    w_id  uuid    NOT NULL REFERENCES workspaces ON DELETE CASCADE,
    tg_id integer NOT NULL REFERENCES tags       ON DELETE CASCADE,
    PRIMARY KEY (w_id, tg_id)
);
CREATE TABLE event_tags (
    ev_id uuid    NOT NULL REFERENCES events ON DELETE CASCADE,
    tg_id integer NOT NULL REFERENCES tags   ON DELETE CASCADE,
    PRIMARY KEY (ev_id, tg_id)
);

-- Notes can reference events (the "Write it, Schedule it" link). Many-to-many.
CREATE TABLE note_event_links (
    n_id  uuid NOT NULL REFERENCES notes  ON DELETE CASCADE,
    ev_id uuid NOT NULL REFERENCES events ON DELETE CASCADE,
    PRIMARY KEY (n_id, ev_id)
);

-- ---------------------------------------------------------------- reminders + email outbox
-- One job per event per reminder kind (lead = X before start, start = at start). The scheduler polls due jobs, fans out into the outbox.
-- Poll with prisma.$queryRaw inside $transaction:  SELECT ... WHERE rj_status='pending' AND rj_fire_at <= now() FOR UPDATE SKIP LOCKED
CREATE TABLE reminder_jobs (
    rj_id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    ev_id        uuid          NOT NULL REFERENCES events ON DELETE CASCADE,
    rj_kind      reminder_kind NOT NULL,
    rj_fire_at   timestamptz   NOT NULL,
    rj_status    job_status    NOT NULL DEFAULT 'pending',
    rj_locked_at timestamptz,
    UNIQUE (ev_id, rj_kind)
);
CREATE INDEX reminder_jobs_due ON reminder_jobs (rj_status, rj_fire_at);

-- Gmail account pool (N-1, v1 stop-gap for testing only). One or more accounts per purpose so a quota problem on reminders can
-- never block a password-reset or verification email. The App Password itself is NOT stored here: ma_secret_ref names the
-- Secrets Manager / SSM parameter that holds it.
CREATE TABLE mail_accounts (
    ma_id          smallint GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    ma_purpose     mail_purpose NOT NULL,
    ma_address     text    NOT NULL UNIQUE CHECK (ma_address = lower(ma_address)),
    ma_secret_ref  text    NOT NULL,
    ma_daily_limit integer NOT NULL DEFAULT 100 CHECK (ma_daily_limit BETWEEN 1 AND 500),   -- start at 100 for new accounts (M2); Gmail's cap is ~500
    ma_enabled     boolean NOT NULL DEFAULT true,
    ma_exhausted_until timestamptz,                    -- set when Gmail itself refuses (quota / lock); skipped until then
    ma_note        text
);

-- Every outgoing email (OTP, invite, reminder, edit/cancel notice ...) goes through here (sent over Gmail SMTP).
-- eo_idempotency_key makes a retry or a double-fired job a no-op, e.g. 'reminder:<ev_id>:lead:<u_id>'.
CREATE TABLE email_outbox (
    eo_id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    u_id                uuid          REFERENCES users ON DELETE CASCADE,
    eo_to_email         text          NOT NULL,       -- recipient (invites go to people who may not have an account yet)
    eo_purpose          mail_purpose  NOT NULL,       -- picks the Gmail pool
    eo_type             text          NOT NULL,       -- 'otp','verify','invite','reminder','event_edited',...
    eo_payload          jsonb         NOT NULL,       -- template variables only; never raw secrets after send
    eo_idempotency_key  text          NOT NULL UNIQUE,
    eo_priority         smallint      NOT NULL DEFAULT 5,  -- 1 = OTP/verify, 3 = invite/notice, 5 = reminder
    eo_status           outbox_status NOT NULL DEFAULT 'pending',
    eo_attempts         smallint      NOT NULL DEFAULT 0,
    eo_mail_account_id  smallint      REFERENCES mail_accounts,   -- account that actually sent it
    eo_provider_msg_id  text,
    eo_created_at       timestamptz   NOT NULL DEFAULT now(),
    eo_send_after       timestamptz   NOT NULL DEFAULT now(),
    eo_sent_at          timestamptz
);
CREATE INDEX email_outbox_due  ON email_outbox (eo_status, eo_priority, eo_send_after);
CREATE INDEX email_outbox_sent ON email_outbox (eo_mail_account_id, eo_status, eo_sent_at);

-- ================================================================ PART 2: database extras (not modelled by Prisma)
-- Keep this whole part in the migration SQL. Prisma will not touch functions or triggers. The three partial UNIQUE indexes are
-- correctness rules: if `prisma db pull` shows any of them WITHOUT its `where`, or a generated migration drops or recreates
-- them, STOP and fix before applying (see PROJECT_PLAN.md, 4.8).

-- One active session per user.
CREATE UNIQUE INDEX one_active_session_per_user ON sessions (u_id) WHERE s_revoked_at IS NULL;
-- One active subscription per user per event.
CREATE UNIQUE INDEX one_active_subscription ON event_subscriptions (ev_id, u_id) WHERE es_unsubscribed_at IS NULL;
-- One pending invite per invitee email per event.
CREATE UNIQUE INDEX one_pending_invite_per_email ON event_invites (ev_id, ei_invitee_email)
    WHERE ei_used_at IS NULL AND ei_revoked_at IS NULL;
-- Prefix search on note titles (expression index).
CREATE INDEX notes_name_idx ON notes (w_id, lower(n_name) text_pattern_ops) WHERE n_deleted_at IS NULL;

-- Retention stamp: <purge_after> = <deleted_at> + days from retention_policy; restoring (deleted_at NULL) clears it.
-- Trigger arguments: TG_ARGV[0] = retention object, TG_ARGV[1] = deleted_at column, TG_ARGV[2] = purge_after column.
CREATE FUNCTION stamp_purge_after() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE d timestamptz; days integer;
BEGIN
    d := (to_jsonb(NEW) ->> TG_ARGV[1])::timestamptz;
    IF d IS NULL THEN
        NEW := jsonb_populate_record(NEW, jsonb_build_object(TG_ARGV[2], NULL));
    ELSIF TG_OP = 'INSERT' OR (to_jsonb(OLD) ->> TG_ARGV[1]) IS DISTINCT FROM (to_jsonb(NEW) ->> TG_ARGV[1]) THEN
        SELECT rp_days INTO days FROM retention_policy WHERE rp_object = TG_ARGV[0];
        NEW := jsonb_populate_record(NEW, jsonb_build_object(TG_ARGV[2], d + make_interval(days => COALESCE(days, 15))));
    END IF;
    RETURN NEW;
END $$;
CREATE TRIGGER users_purge_stamp      BEFORE INSERT OR UPDATE OF us_deleted_at ON users
    FOR EACH ROW EXECUTE FUNCTION stamp_purge_after('account',   'us_deleted_at', 'us_purge_after');
CREATE TRIGGER workspaces_purge_stamp BEFORE INSERT OR UPDATE OF w_deleted_at  ON workspaces
    FOR EACH ROW EXECUTE FUNCTION stamp_purge_after('workspace', 'w_deleted_at',  'w_purge_after');
CREATE TRIGGER notes_purge_stamp      BEFORE INSERT OR UPDATE OF n_deleted_at  ON notes
    FOR EACH ROW EXECUTE FUNCTION stamp_purge_after('note',      'n_deleted_at',  'n_purge_after');
CREATE TRIGGER events_purge_stamp     BEFORE INSERT OR UPDATE OF ev_deleted_at ON events
    FOR EACH ROW EXECUTE FUNCTION stamp_purge_after('event',     'ev_deleted_at', 'ev_purge_after');

-- timestamptz + interval is only STABLE, so the event end cannot be a generated column; use a trigger.
CREATE FUNCTION set_event_end() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    NEW.ev_end_at     := NEW.ev_start_at + make_interval(mins => NEW.ev_duration_min);
    NEW.ev_updated_at := now();
    RETURN NEW;
END $$;
CREATE TRIGGER events_set_end BEFORE INSERT OR UPDATE OF ev_start_at, ev_duration_min ON events
    FOR EACH ROW EXECUTE FUNCTION set_event_end();

-- Note lock: take or renew it (the heartbeat calls the same function). Returns true if the caller now holds it.
-- Same session renews; an expired lock can be taken over; otherwise false. Membership/permission is checked by the API first.
-- Call from Prisma:  prisma.$queryRaw`SELECT acquire_note_lock(${noteId}::uuid, ${userId}::uuid, ${sessionId}::uuid) AS ok`
CREATE FUNCTION acquire_note_lock(p_n uuid, p_u uuid, p_s uuid, p_ttl interval DEFAULT interval '2 minutes')
RETURNS boolean LANGUAGE plpgsql AS $$
DECLARE got uuid;
BEGIN
    INSERT INTO note_locks AS l (n_id, u_id, s_id, nl_expires_at)
    VALUES (p_n, p_u, p_s, now() + p_ttl)
    ON CONFLICT (n_id) DO UPDATE
        SET u_id = EXCLUDED.u_id, s_id = EXCLUDED.s_id, nl_heartbeat_at = now(), nl_expires_at = now() + p_ttl,
            nl_acquired_at = CASE WHEN l.s_id = EXCLUDED.s_id THEN l.nl_acquired_at ELSE now() END
        WHERE l.s_id = EXCLUDED.s_id OR l.nl_expires_at < now()
    RETURNING n_id INTO got;
    RETURN got IS NOT NULL;
END $$;

-- Owner take-over (M4): only the owner of the note's workspace may replace someone else's live lock. Returns false for anyone else.
CREATE FUNCTION take_over_note_lock(p_n uuid, p_owner uuid, p_s uuid, p_ttl interval DEFAULT interval '2 minutes')
RETURNS boolean LANGUAGE plpgsql AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM notes n JOIN workspaces w ON w.w_id = n.w_id
                    WHERE n.n_id = p_n AND w.u_id = p_owner AND n.n_deleted_at IS NULL AND w.w_deleted_at IS NULL) THEN
        RETURN false;
    END IF;
    INSERT INTO note_locks AS l (n_id, u_id, s_id, nl_expires_at)
    VALUES (p_n, p_owner, p_s, now() + p_ttl)
    ON CONFLICT (n_id) DO UPDATE
        SET u_id = EXCLUDED.u_id, s_id = EXCLUDED.s_id, nl_acquired_at = now(), nl_heartbeat_at = now(), nl_expires_at = now() + p_ttl;
    RETURN true;
END $$;

-- A revoked session frees its locks at once.
CREATE FUNCTION release_locks_on_revoke() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM note_locks WHERE s_id = NEW.s_id;
    RETURN NEW;
END $$;
CREATE TRIGGER sessions_release_locks AFTER UPDATE OF s_revoked_at ON sessions
    FOR EACH ROW WHEN (NEW.s_revoked_at IS NOT NULL) EXECUTE FUNCTION release_locks_on_revoke();

-- Pick the account to send with: enabled, not exhausted, still under its rolling-24h budget. Least-used first.
-- Returns NULL when every account of that purpose is used up: the worker leaves the email pending and retries on the next poll.
-- This is a budget estimate, not a Gmail guarantee; a hard refusal from Gmail sets ma_exhausted_until.
CREATE FUNCTION pick_mail_account(p_purpose mail_purpose, p_recipients integer DEFAULT 1)
RETURNS smallint LANGUAGE sql STABLE AS $$
    SELECT a.ma_id
      FROM mail_accounts a
      LEFT JOIN LATERAL (SELECT count(*) AS n FROM email_outbox o
                          WHERE o.eo_mail_account_id = a.ma_id AND o.eo_status = 'sent'
                            AND o.eo_sent_at > now() - interval '24 hours') s ON true
     WHERE a.ma_purpose = p_purpose AND a.ma_enabled
       AND (a.ma_exhausted_until IS NULL OR a.ma_exhausted_until < now())
       AND s.n + p_recipients <= a.ma_daily_limit
     ORDER BY s.n ASC, a.ma_id
     LIMIT 1
$$;

-- ================================================================ PART 3: seed data
INSERT INTO retention_policy (rp_object) VALUES ('account'), ('workspace'), ('note'), ('event');
INSERT INTO language_types (lt_id, lt_code, lt_name, lt_is_rtl, lt_description) VALUES
    (1, 'en', 'English',  false, 'Default'),
    (2, 'fr', 'Français', false, 'French'),
    (3, 'ar', 'العربية',   true,  'Arabic (right-to-left)');
INSERT INTO theme_types (tt_id, tt_name, tt_colors, tt_description) VALUES
    (1, 'Light', '{"bg":"#ffffff","fg":"#1b1b1f","accent":"#6a00ff"}', 'Default light theme'),
    (2, 'Dark',  '{"bg":"#14141a","fg":"#ececf1","accent":"#a78bfa"}', 'Default dark theme');
-- 12 predefined tags (M9 accepted). tg_name must equal tg_data->>'name'.
INSERT INTO tags (tg_name, tg_data) VALUES
    ('Work',     '{"name":"Work","color":"#1ba1e2","description":"Professional items"}'),
    ('Personal', '{"name":"Personal","color":"#60a917","description":"Personal items"}'),
    ('Study',    '{"name":"Study","color":"#fa6800","description":"Courses and revision"}'),
    ('Urgent',   '{"name":"Urgent","color":"#e51400","description":"Needs attention soon"}'),
    ('Meeting',  '{"name":"Meeting","color":"#6a00ff","description":"Calls and meetings"}'),
    ('Project',  '{"name":"Project","color":"#0050ef","description":"Project work and milestones"}'),
    ('Ideas',    '{"name":"Ideas","color":"#f0a30a","description":"Brainstorms and drafts"}'),
    ('Health',   '{"name":"Health","color":"#008a00","description":"Health and fitness"}'),
    ('Finance',  '{"name":"Finance","color":"#825a2c","description":"Budgets and bills"}'),
    ('Travel',   '{"name":"Travel","color":"#00aba9","description":"Trips and bookings"}'),
    ('Family',   '{"name":"Family","color":"#d80073","description":"Family and friends"}'),
    ('Reminder', '{"name":"Reminder","color":"#647687","description":"Things not to forget"}');
-- Example mail pool rows (placeholders; the App Passwords live in the secret store, never here):
-- INSERT INTO mail_accounts (ma_purpose, ma_address, ma_secret_ref) VALUES
--   ('security', '[security gmail address]', '/scribbl/mail/security1'),
--   ('reminder', '[reminder gmail address]', '/scribbl/mail/reminder1'),
--   ('invite',   '[invite gmail address]',   '/scribbl/mail/invite1');
