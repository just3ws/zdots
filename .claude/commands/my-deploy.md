# /my-deploy — Deploy context-engine to production

Runs the full local deploy cycle for the context-engine Rails app at `~/my/context-engine`.

## What it does

```bash
cd ~/my/context-engine
bin/deploy   # bundle install → RAILS_ENV=production assets:precompile → touch tmp/restart.txt → curl /up
```

## When to use

- After editing any CSS, JS, or asset file
- After changing gems (Gemfile)
- After pulling new commits to ~/my
- After any Rails config change that doesn't hot-reload

## Verify

```bash
curl -sk https://my.local/up        # → 200 OK
curl -sk https://my.local/ | head   # dashboard HTML
```

## Puma restart only (no asset change)

```bash
touch ~/my/context-engine/tmp/restart.txt
```

## Model / effort
Use **haiku** at **low** effort — this is a mechanical execution task, not reasoning.
