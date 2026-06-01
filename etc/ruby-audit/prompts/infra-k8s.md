# Docker & Kubernetes (k9s) Analysis Context

This rule-pack covers local containerized development via Docker Compose and production orchestration via Kubernetes, with k9s as the primary terminal UI.

## Docker & Dockerfile
*   **Base Image**: Prefer official Ruby images (e.g., `ruby:3.2-slim`). Avoid heavy images unless specific build dependencies are required.
*   **Layer Optimization**: Group `RUN` commands to reduce layer count. Use multi-stage builds to separate build-time dependencies (e.g., `build-essential`, `libpq-dev`) from the runtime image.
*   **Caching**: Copy `Gemfile` and `Gemfile.lock` first, run `bundle install`, then copy the rest of the application to leverage layer caching.
*   **User Safety**: Never run the application as `root`. Use a dedicated `ruby` user.
*   **Health Checks**: Implement `HEALTHCHECK` instructions in the Dockerfile to assist orchestration liveness probes.

## Docker Compose (Local Dev)
*   **Volumes**: Use named volumes for database persistence and bind mounts for live code reloading.
*   **Networks**: Use internal networks to isolate services. Ensure the Rails app can resolve dependencies (DB, Redis) by service name.
*   **Environment**: Keep secrets out of `docker-compose.yml`. Use `.env` files (but don't commit them).
*   **Dependencies**: Use `depends_on` with `condition: service_healthy` to ensure the DB is ready before Rails boots.

## Kubernetes Deployment
*   **Resources**: Always define `requests` and `limits` for CPU and Memory to prevent OOMKills and noisy neighbor issues.
*   **Probes**: Define `livenessProbe` and `readinessProbe`. Use the Rails `/health` or `/up` endpoint.
*   **ConfigMaps & Secrets**: Use ConfigMaps for non-sensitive config and Secrets for sensitive data (API keys, DB credentials).
*   **Service Types**: Use `ClusterIP` for internal services and `Ingress` for external access.
*   **Sidecars**: Check for OTel collectors or logging sidecars that might impact resource usage.

## k9s Operational Hygiene
*   **Context**: Always verify the current context (Cluster/Namespace) before performing destructive actions.
*   **Logs**: Use `<L>` to tail logs or `<s>` to shell into a pod for quick debugging.
*   **Port Forwarding**: Use `<shift-f>` to forward local ports to services for ad-hoc debugging.
*   **Resource Monitoring**: Use `cpu` and `mem` columns to identify resource-heavy pods.
*   **Commands**: Custom aliases in `skin.yml` or `plugin.yml` can speed up common Rails tasks (e.g., `bundle exec rails c`).

## Common Pitfalls
*   **Local vs Remote**: Discrepancies between the `docker-compose` environment and the Kubernetes manifests (e.g., different environment variable names or service endpoints).
*   **Missing Labels**: Ensure consistent labels for service discovery and log aggregation.
*   **Persistence**: Forgetting that pod storage is ephemeral; ensure `PersistentVolumeClaims` are used where needed.
