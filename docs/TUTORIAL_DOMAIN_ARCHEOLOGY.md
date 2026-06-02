# Tutorial: Rails Platform Domain Archeology

This tutorial guides you through the process of mapping the domain complexity of a legacy Rails application on your work machine, enabling informed decisions for modernization while maintaining a read-only, build-only environment.

## 1. Prerequisites
- **Repository Access**: Cloned Rails codebase (e.g., `just3ws/ccs`).
- **Environment**: Zdots environment initialized (`zdots-update-local`).
- **Ruby Runtime**: Ruby 2.6.10 available via `mise`.
- **System Dependencies**: `libxml2`, `libxslt`, `mariadb-connector-c`, `memcached`, `mongodb-database-tools` (installed via Homebrew).

---

## 2. Setup the Knowledge Vault
Ensure your `~/my` directory structure is aligned. Run this in your home terminal:

```bash
zdots-my-sync
```

This creates the necessary subdirectories (`backlog/`, `standards/`, `models/`, etc.) for organizing your inventory.

---

## 3. Configure Bundler (The Build-Only Setup)
Before installing gems for analysis, configure Bundler to link against your local Homebrew headers. Run this **inside** your target Rails project root:

```bash
cd /path/to/rails-project
zdots-ruby-legacy-setup
bundle install
```

*Note: This configuration is persisted in the project's local `.bundle/config` and does not affect your global system configuration.*

---

## 4. Extracting Domain Assets
Use the `zdots-archeologist` tool to extract schema and association metadata. This is safe, read-only analysis.

```bash
# Example: Mapping the User model
bin/zdots-archeologist User > ~/my/standards/models/user.json
```

---

## 5. Documenting & Distilling
Create a **Domain Asset Report** in the `~/my` structure. 

1. **Create the file**: `~/my/standards/models/user.md`.
2. **Populate**: Add the JSON output and your observations using the standard template:

```markdown
# Asset: User

## Structural Schema
```json
{ ... JSON content here ... }
```

## Domain Insights
- **Complexity**: (e.g., High - God Model)
- **Coupling**: (e.g., Highly coupled to Order/Payment models)
- **Workflow Role**: (e.g., Delayed Job trigger)

## Migration/Resilience Gaps
- [ ] Refactor `after_save` callback.
- [ ] Decouple from legacy Payment API.
```

3. **Distill (Optional)**: If you need to refine the markdown, pipe it through Pi:
   ```bash
   cat ~/my/standards/models/user.md | pi --system "Improve grammar and clarity" > ~/my/standards/models/user_final.md
   ```

---

## 6. Indexing into the Brain
Finally, ingest your findings so you can query them across the entire codebase.

```bash
zdots-ctx ingest ~/my/standards/models/
```

**Querying Your Inventory:**
Once indexed, you can ask the Brain questions like:
> "Which models are coupled to the Order model and have high complexity?"
> "What are the common resilience gaps identified in the Delayed Job workflows?"

---

## Pro-Tips for Ownership
- **Mermaid Diagrams**: After generating a few `user.json` files, I can help you automate the creation of ER diagrams to visualize the entire domain.
- **Backlog Tracking**: Use `zdots-issue` to turn any "Migration/Resilience Gap" in your MD reports into an actionable task in your backlog.
- **Focus on Coupling**: When exploring models, pay attention to `belongs_to` and `has_many` associations—these are the "fault lines" for modernization.
