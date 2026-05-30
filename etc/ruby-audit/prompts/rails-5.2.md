# Rails 5.2 Analysis Context

Rails 5.2 reached end-of-maintenance June 2022. No security patches are released.
The last 5.2.x release was 5.2.8.1 (a security backport). Any app still on 5.2 in
production is accumulating unpatched CVEs in the framework itself.

## What exists in 5.2 (orientation)

- `ActiveStorage` — introduced in 5.2 (file attachments backed by cloud/disk)
- `Credentials` — `config/credentials.yml.enc` replaces `config/secrets.yml`
- `Content Security Policy` DSL in config
- `ActiveRecord` — `ActiveRecord::Base.connection_pool` management
- `ActionCable` — WebSocket support (since 5.0)
- `ActiveJob` — background jobs (since 4.2)
- `Webpacker` optional but commonly added at 5.x
- No `Action Mailbox` (6.0+), no `Action Text` (6.0+), no `Hotwire` (7.0+)
- No `encrypted attributes` in ActiveRecord (7.0+)
- No `Zeitwerk` autoloader — uses `Classic` autoloader (Zeitwerk opt-in in 6.0, default in 6.1)

## Security patterns common in 5.2 to audit

### Mass assignment
- `strong_parameters` is present since 4.x — look for `permit!` (unrestricted) and
  over-permissive permit lists
- `attr_accessible` / `attr_protected` are gone (removed in 4.0) but old comments may mislead

### Authentication / authorization
- No built-in auth (common gems: Devise, Clearance, Sorcery)
- Look for `before_action :authenticate_user!` coverage — check for gaps
- `skip_before_action` — any controller skipping auth filters needs scrutiny
- `current_user` calls in models (should only be in controllers/views)

### SQL injection
- `where("column = '#{value}'")` — string interpolation in where clauses
- `.order(params[:sort])` — user-controlled sort column
- `find_by_sql` with interpolation
- `execute` / `connection.execute` with string building

### Template injection / XSS
- `html_safe` and `raw` — mark for manual review
- ERB templates: `<%=` is escaped, `<%= raw %>` is not
- `render inline:` — dangerous pattern
- Content-Type response headers — check JSON endpoints

### File upload (ActiveStorage)
- Direct upload without content-type validation
- Service-side access control on stored blobs
- Public vs private storage configuration

### Serialization
- `Marshal.load` from cache/sessions — dangerous if session store is cookie-based
  and secret_key_base is leaked
- YAML deserialization in any form — flag `YAML.load` (should be `YAML.safe_load`)
- `JSON.load` vs `JSON.parse` — `JSON.load` is unsafe

## Rails 5.2 → 6.0 upgrade notes

Key breaking changes:
- Classic → Zeitwerk autoloader: `require_dependency` calls break; `app/` structure must be idiomatic
- `ActionDispatch::Http::UploadedFile` behavior changes
- Keyword argument changes begin (2.7 Ruby required for 6.x)
- `db:schema:load` → `db:schema:load` (same command, but schema format changes possible)
- `belongs_to` is required by default (since 5.0, but apps often have `optional: true` missing)
- `update_attributes` removed (deprecated in 6.0, use `update`)
- `redirect_back` removed (use `redirect_back_or_to`)
- ActionMailer `deliver` removed (use `deliver_now`)

## Common architectural patterns in 5.2 apps

- Fat models / skinny controllers (but often neither in practice)
- Service objects: look for `app/services/`, `app/operations/`, `app/use_cases/`
- Concerns: `app/models/concerns/`, `app/controllers/concerns/`
- Presenters/decorators: Draper or plain PORO wrappers
- Background jobs: Sidekiq, Resque, Delayed::Job — check for retry logic and idempotency
- API: `ActionController::API` base class vs full `ApplicationController`
