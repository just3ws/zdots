# Archived SQL Migrations

These files (001–009) are the original hand-written SQL migrations for the
`my` PostgreSQL database. They have been superseded by the Sequel migration
system introduced in May 2026.

**Do not apply these files.** The authoritative migrations live at:

    db/migrations/20260514000000_baseline.rb       ← consolidates 001–008 + part of 009
    db/migrations/20260515000000_add_job_functions.rb

The Sequel migrator is invoked via:

    zdots-ctx migrate

Tracked in: `zdots_schema_migrations` table (managed by Sequel).
