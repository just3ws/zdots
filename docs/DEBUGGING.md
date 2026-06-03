# Zdots Environment Debugging Guide

This guide provides actionable "If this, then that" troubleshooting paths for common failure points in the Zdots environment.

## 1. Quick Start: The "Is it Healthy?" Flow
If the environment behaves unexpectedly, always run the aggregate health check:

```bash
zdots-ctl status
```

If any service is red, proceed to the specific component flows below.

---

## 2. Troubleshooting Flows

### Flow A: Database Connection Failure
*Symptom: `zdots-ctx` fails to connect, `make check` reports database issues.*

1.  **Check Colima**: Ensure the container runtime is running.
    *   Command: `colima status`
    *   If down: `colima start`
2.  **Verify Credential Injection**:
    *   Command: `zdots-ctx status`
    *   If failure: Your Keychain password may be out of sync. Rotate them:
        ```bash
        bin/zdots-ctx rotate-creds --all
        ```
3.  **Check Process**: Ensure Postgres is listening.
    *   Command: `pg_isready`

### Flow B: Service Lifecycle Failure
*Symptom: A service (llama, redis, otel) fails to start or respond.*

1.  **Registry Check**:
    *   Command: `zsvc list`
    *   If service is missing: Register it via `zsvc <service> install`.
2.  **Health Probe**:
    *   Command: `zsvc health --json`
    *   Identify the failing probe.
3.  **Log Analysis**:
    *   Command: `zsvc logs <service>`
    *   *Tip*: Use `zsvc logs all` to tail logs across all components to find correlated errors (e.g., Redis failing before AI server).

### Flow C: AI Query / Context Failure
*Symptom: `zdots-ctx query` returns empty or errors; Pi agent failing.*

1.  **Model Availability**: Check if the local inference server is up.
    *   Command: `curl http://127.0.0.1:11500/health`
    *   If down: `zsvc restart llama`
2.  **Database Hydration**: Check if the Brain has indexed your docs.
    *   Command: `zdots-ctx status` (check methodology/lesson counts).
    *   If 0: Your `~/my` directory might not be ingested. Run `zdots-ctx ingest ~/my/standards/`.

---

## 3. Likely "Disconnect Points"
*Common areas where the system state drifts.*

*   **Credential/Keychain Drift**: `zdots-ctx` depends on the keychain. If you change DB roles or manually tweak Postgres, `bin/zdots-ctx rotate-creds --all` is your immediate fix.
*   **Missing Dependencies**: `brew bundle` may be out of sync. Always run `brew bundle check` if tests fail inexplicably.
*   **XDG Compliance**: If services fail to write logs, ensure `$XDG_STATE_HOME` or `~/.local/state` exists and is writable.
*   **Colima/Docker Socket**: If Postgres/Redis fail to start but appear registered, verify the Docker socket is present: `ls /Users/mike/.colima/default/docker.sock`.

---

## 4. When to stop and file a ticket
If you have performed the above checks and the component manager (e.g., `zsvc`) reports it is in a "Degraded" state that resists a `zsvc restart <service>`, **do not continue to patch the internal state.** 

File a ticket:
```bash
zdots-issue --title "Environment drift in <component>: <symptom>"
```
Include the output of `zdots-ctl status` in the issue description.
