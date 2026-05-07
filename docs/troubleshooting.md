# Troubleshooting Guide

Common issues and their resolutions.

## 1. Platform & Startup

### Shell takes too long to load
- Run `make bench` to identify the bottleneck.
- Check if `atuin` or `direnv` are responding slowly.
- Use `ZDOTS_SAFE_MODE=1` to bypass all modules and confirm it's a shell-specific issue.

### Service "Bootstrap failed: 5: Input/output error"
This usually means a `launchd` service is already running or the model file is corrupted.
- Run `zdots-ctl reset` to perform a clean restart of all services.
- Run `llama-ctl status` to check model integrity.

## 2. AI Inference

### "Invalid magic characters: 'Inva'" in llama logs
This means the GGUF file is actually a text file (likely a 401 error page from HuggingFace).
- Run `rm ~/.local/share/llama-cpp/models/*.gguf`.
- Add a valid `HUGGINGFACE_TOKEN` to your `.env`.
- Re-run `llama-ctl model-download`.

### AI server unreachable (8080)
- Confirm the server is running: `llama-ctl status`.
- Check logs for crashes: `llama-ctl logs`.
- Check if another process is using port 8080: `lsof -i :8080`.

## 3. Observability

### No traces in Grafana
- Ensure the collector is running: `otel-collector status`.
- Ensure the LGTM stack is up: `local-ci status`.
- Check connectivity: `otel-collector health`.
- Verify the forwarder is working: `otel-collector logs` (look for "Exporting failed").

### Colima fails to start
- Check Colima status: `colima status`.
- Try a hard rebuild: `local-ci rebuild` (⚠️ WARNING: Deletes the VM).

## 4. Diagnostics

Always run the deep check first when something feels wrong:
```sh
zdots-ctl check
```
It provides actionable fix hints for most common issues.
