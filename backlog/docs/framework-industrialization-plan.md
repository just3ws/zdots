# Architectural Plan: Zdots Industrialization (Ruby + Sequel)

## 1. Objective
Transition the Zdots "Brain" from monolithic Bash scripts to a modular Ruby-based Control Plane leveraging the `Sequel` ORM and `RubyLLM` for consistent intelligence management.

## 2. Technical Stack
- **Language**: Ruby 3.x
- **Database Logic**: `Sequel` ORM for Postgres.
- **AI/LLM Logic**: `RubyLLM` for local-first inference and embeddings.
- **Contract**: `zdots-ctx` (Bash) as a thin wrapper for `sbin/zdots-brain` (Ruby).
- **Modularity**: Individual Job classes in `lib/zdots/jobs/`.

## 3. Reference Architecture
Inspiration taken from `~/github.com/wwworkremote/core`:
- Modular service boundaries.
- Clean separation between models (State) and jobs (Execution).
- Standardized AI context passing.

## 4. Key Components

### A. The Ruby Brain Core (`lib/zdots`)
- `lib/zdots/brain.rb`: The primary entry point for the Ruby platform.
- `lib/zdots/db.rb`: Sequel database configuration and connection management.
- `lib/zdots/models/`:
  - `Job`: Sequel model for the `jobs` table, wrapping stored procs.
  - `Lesson`: Sequel model for the `lessons` table with `pgvector` support.
  - `Methodology`: Sequel model for the `methodologies` table.

### B. Asynchronous Job System (`lib/zdots/jobs`)
Replace the `case` statement in `bin/zdots-ctx` with a dynamic loader:
- `lib/zdots/jobs/base.rb`: Common retry/OTel/logging logic.
- `lib/zdots/jobs/transcription.rb`: Handles YouTube media logic.
- `lib/zdots/jobs/embed.rb`: Handles `RubyLLM` embedding generation.
- `lib/zdots/jobs/distill.rb`: Handles `RubyLLM` distillation.

### C. The Manifest (`lib/zdots/manifest.rb`)
- A single Ruby-defined manifest (cached in Postgres) for all system capabilities.
- Automatically generates `agent-guide`, `ctx-mcp` tools, and command-line help.

## 5. Migration Roadmap

### Phase 1: Foundations
- Create `Gemfile` with `sequel`, `pg`, `ruby_llm`, `pgvector`, and `opentelemetry` gems.
- Scaffold `lib/zdots/` directory structure.
- Implement the `Sequel` connection manager.

### Phase 2: Job Broker Port
- Port `claim_next_job` usage to Ruby.
- Implement `BaseJob` with integrated OTel span emission.
- Port `transcription`, `distill`, and `embed` logic to individual classes.

### Phase 3: Metadata & Intelligence
- Port `add-methodology`, `add-lesson`, and `query` to Ruby.
- Implement `pgvector` similarity search using Sequel's DSL.

### Phase 4: Discovery Sync
- Refactor `bin/agent-guide` and `bin/ctx-mcp` to use the Ruby manifest.

## 6. Verification & Safety
- **Portability**: Ensure `make bootstrap` correctly handles `bundle install`.
- **Hybrid Support**: Maintain Bash compatibility for high-performance terminal start-up.
- **Backups**: Ensure Ruby core can trigger the `pg_dump` backup logic.
