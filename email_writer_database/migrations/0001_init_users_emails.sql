-- NOTE:
-- This project’s database is provisioned as PostgreSQL (see db_connection.txt).
-- The live environment already contains these objects, but this file is kept as
-- in-repo evidence/DDL tracking for the expected schema per the SRS.
--
-- Apply manually (one statement at a time) using the command in db_connection.txt:
--   psql postgresql://... -c "<STATEMENT>"
--
-- SRS minimum:
--   Users: user_id, name, email, password_hash, created_at
--   Emails: email_id, user_id, subject, content, tone, created_at
--
-- Implementation notes:
-- - Uses UUID primary keys (id) instead of user_id/email_id naming, but equivalent.
-- - Uses CITEXT for case-insensitive unique emails.
-- - Adds updated_at + trigger for auditing (superset of SRS).
-- - Adds FK emails.user_id -> users.id with ON DELETE CASCADE.
-- - Adds indexes for efficient user email history queries.

-- 1) Extensions (required for gen_random_uuid() and case-insensitive email)
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS citext;

-- 2) updated_at trigger function
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

-- 3) users table
CREATE TABLE IF NOT EXISTS public.users (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name          text NOT NULL,
  email         citext NOT NULL,
  password_hash text NOT NULL,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT users_email_unique UNIQUE (email),
  CONSTRAINT users_name_check CHECK (char_length(name) >= 1 AND char_length(name) <= 200)
);

DROP TRIGGER IF EXISTS trg_users_set_updated_at ON public.users;
CREATE TRIGGER trg_users_set_updated_at
BEFORE UPDATE ON public.users
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

-- 4) emails table
CREATE TABLE IF NOT EXISTS public.emails (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  subject    text NOT NULL DEFAULT '',
  content    text NOT NULL,
  tone       text NOT NULL DEFAULT 'neutral',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT emails_subject_check CHECK (char_length(subject) <= 500),
  CONSTRAINT emails_tone_check CHECK (char_length(tone) <= 50)
);

DROP TRIGGER IF EXISTS trg_emails_set_updated_at ON public.emails;
CREATE TRIGGER trg_emails_set_updated_at
BEFORE UPDATE ON public.emails
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

-- 5) Indexes (history queries)
CREATE INDEX IF NOT EXISTS idx_emails_user_id_created_at
  ON public.emails (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_emails_user_id_updated_at
  ON public.emails (user_id, updated_at DESC);
