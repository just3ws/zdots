---
name: my-deploy
description: Deploy context-engine to local production (my.local). Use when assets, gems, or Rails config changed and Puma needs a full redeploy rather than just a restart.
---

# /my-deploy — Deploy context-engine to production

Runs the full local deploy cycle for the context-engine Rails app at `~/my/context-engine`.

## What it does

```bash
cd ~/my/context-engine
bin/deploy   # libyaml build flag → bundle install → assets:precompile → touch tmp/restart.txt → verify /up
```

## When to use

- After editing any CSS, JS, or asset file (propshaft must fingerprint)
- After changing gems (Gemfile / Gemfile.lock)
- After pulling new commits to `~/my`
- After any Rails config change that doesn't hot-reload

## Puma restart only (no asset change)

```bash
touch ~/my/context-engine/tmp/restart.txt
```

## Verify (operator console routes)

```bash
curl -sk https://my.local/up                  # → 200 OK
curl -sk https://my.local/                     # dashboard + live health badges
curl -sk https://my.local/platform             # service health table
curl -sk https://my.local/docs                 # zdots docs browser
curl -sk https://my.local/docs/guide/agents    # a rendered doc
```

## Troubleshooting

- **`bundle install` fails building psych (`yaml.h not found`)**: psych 5.3.x bakes a
  search path for a `portable-libyaml` formula that isn't installed. `bin/deploy`
  sets `bundle config build.psych --with-libyaml-dir=$(brew --prefix libyaml)` to fix
  it; if running bundle by hand, export that or run `bin/deploy`.
- **CSS 404s after a style change**: assets weren't precompiled — run `bin/deploy`,
  not just `touch tmp/restart.txt`. `public/assets/` is gitignored (precompile output).
- **`/platform` shows a service down**: probes are direct HTTP/DB. Check the service
  with `zsvc status <svc>` in a shell — the page never shells out to zsvc.

## Notes

- Puma is managed by launchd (`com.my.context-engine-api`); `tmp/restart.txt` triggers graceful reload
- If Puma is not running: `launchctl start com.my.context-engine-api`
- App is Sequel, not ActiveRecord — no `create!`/`save!`, jsonb needs `Sequel.pg_jsonb`

## Model / effort

Use **haiku** at **low** effort — mechanical execution, not reasoning.
