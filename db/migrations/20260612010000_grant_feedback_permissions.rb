# frozen_string_literal: true

Sequel.migration do
  up do
    # Grant permissions to application users for operational feedback tables
    run "GRANT SELECT, INSERT, UPDATE ON operational_feedback TO zdots_rw"
    run "GRANT SELECT ON operational_feedback TO zdots_ro"
    run "GRANT USAGE, SELECT ON SEQUENCE operational_feedback_id_seq TO zdots_rw"

    run "GRANT SELECT, INSERT, UPDATE ON recommendations TO zdots_rw"
    run "GRANT SELECT ON recommendations TO zdots_ro"
    run "GRANT USAGE, SELECT ON SEQUENCE recommendations_id_seq TO zdots_rw"
  end

  down do
    # Revoke permissions
    run "REVOKE SELECT, INSERT, UPDATE ON operational_feedback FROM zdots_rw"
    run "REVOKE SELECT ON operational_feedback FROM zdots_ro"
    run "REVOKE USAGE, SELECT ON SEQUENCE operational_feedback_id_seq FROM zdots_rw"

    run "REVOKE SELECT, INSERT, UPDATE ON recommendations FROM zdots_rw"
    run "REVOKE SELECT ON recommendations FROM zdots_ro"
    run "REVOKE USAGE, SELECT ON SEQUENCE recommendations_id_seq FROM zdots_rw"
  end
end
