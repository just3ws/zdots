# frozen_string_literal: true

Sequel.migration do
  up do
    run <<~SQL
      DO $$ BEGIN
        IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'zdots_reader') THEN
          CREATE ROLE zdots_reader;
        END IF;
      END $$;

      DO $$ BEGIN
        IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'zdots_writer') THEN
          CREATE ROLE zdots_writer;
        END IF;
      END $$;

      GRANT SELECT ON jobs, lessons, methodologies, session_residue TO zdots_reader;

      GRANT zdots_reader TO zdots_writer;
      GRANT INSERT, UPDATE, DELETE ON jobs, lessons, methodologies, session_residue TO zdots_writer;
      GRANT EXECUTE ON FUNCTION claim_next_job(text, text), fail_job(uuid, text), complete_job(uuid) TO zdots_writer;

      DO $$ BEGIN
        IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'zdots_ro') THEN
          CREATE USER zdots_ro;
        END IF;
      END $$;
      GRANT zdots_reader TO zdots_ro;

      DO $$ BEGIN
        IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'zdots_rw') THEN
          CREATE USER zdots_rw;
        END IF;
      END $$;
      GRANT zdots_writer TO zdots_rw;

      ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO zdots_reader;
      ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT INSERT, UPDATE, DELETE ON TABLES TO zdots_writer;
      ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO zdots_writer;
    SQL
  end

  down do
    run <<~SQL
      DROP OWNED BY zdots_rw;
      DROP OWNED BY zdots_ro;
      DROP USER IF EXISTS zdots_rw;
      DROP USER IF EXISTS zdots_ro;
      DROP ROLE IF EXISTS zdots_writer;
      DROP ROLE IF EXISTS zdots_reader;
    SQL
  end
end
