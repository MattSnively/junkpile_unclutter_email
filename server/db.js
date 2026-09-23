/**
 * db.js — Postgres connection pool and schema bootstrap.
 *
 * Railway injects DATABASE_URL when a Postgres service is attached. The
 * internal URL (postgres.railway.internal) needs no TLS; a public proxy URL
 * should carry ?sslmode=no-verify because Railway's cert is self-signed.
 */

const { Pool } = require('pg');

if (!process.env.DATABASE_URL) {
    throw new Error('DATABASE_URL is not set — attach a Postgres service or point at a local instance');
}

const pool = new Pool({ connectionString: process.env.DATABASE_URL });

/**
 * Creates tables on first boot. Idempotent, so it runs on every startup
 * instead of requiring a separate migration step for two tables.
 */
async function initSchema() {
    await pool.query(`
        CREATE TABLE IF NOT EXISTS users (
            id            UUID PRIMARY KEY,
            apple_user_id TEXT UNIQUE,
            email         TEXT NOT NULL,
            name          TEXT,
            auth_provider TEXT NOT NULL,
            gmail_tokens  JSONB,
            gmail_email   TEXT,
            created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
            last_login_at TIMESTAMPTZ NOT NULL DEFAULT now()
        );

        CREATE TABLE IF NOT EXISTS decisions (
            id                 BIGSERIAL PRIMARY KEY,
            user_key           TEXT NOT NULL,
            email_id           TEXT NOT NULL,
            decision           TEXT NOT NULL,
            unsubscribe_method TEXT,
            sender_address     TEXT,
            created_at         TIMESTAMPTZ NOT NULL DEFAULT now()
        );

        -- Columns added after the tables shipped; CREATE TABLE IF NOT EXISTS won't add them
        ALTER TABLE decisions ADD COLUMN IF NOT EXISTS sender_address TEXT;
        ALTER TABLE users ADD COLUMN IF NOT EXISTS apple_tokens JSONB;

        CREATE INDEX IF NOT EXISTS decisions_user_key_idx ON decisions (user_key);
    `);
}

module.exports = { pool, initSchema };
