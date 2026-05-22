-- etc/db/migrations/005_dlq_status.sql
-- Add 'dead' status to job_status ENUM

ALTER TYPE job_status ADD VALUE IF NOT EXISTS 'dead';
