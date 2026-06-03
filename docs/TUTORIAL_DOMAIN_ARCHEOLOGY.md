# Tutorial: Rails Platform Domain Archeology

This tutorial guides you through the process of mapping the domain complexity of a legacy Rails application on your work machine, enabling informed decisions for modernization while maintaining a read-only, build-only environment.

## 1. Prerequisites
- **Repository Access**: Cloned Rails codebase (e.g., `just3ws/ccs`).
- **Environment**: Zdots environment initialized (`zdots-update-local`).
- **Ruby Runtime**: Ruby 2.6.10 available via `mise`.
- **System Dependencies**: Install the optional module dependencies:

```bash
brew bundle --file "$ZDOTDIR/modules/rails-modernization/Brewfile"
```

For short command names in the current shell:

```bash
export PATH="$ZDOTDIR/modules/rails-modernization/bin:$PATH"
```

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
"$ZDOTDIR/modules/rails-modernization/bin/zdots-ruby-legacy-setup"
bundle install
```

*Note: This configuration is persisted in the project's local `.bundle/config` and does not affect your global system configuration.*

---

## 4. Mapping Domain Assets (The Automated Way)
Use the `zdots-archeologist-run` utility to automatically extract, map, and organize assets from a repository.

```bash
# Usage: zdots-archeologist-run <git_url> <ModelName>
"$ZDOTDIR/modules/rails-modernization/bin/zdots-archeologist-run" git@github.com:just3ws/ccs.git User
```

This command automatically:
1.  **Extracts** the model's schema and associations into JSON.
2.  **Visualizes** the model structure as a Mermaid ER diagram.
3.  **Organizes** all artifacts into: `~/my/analysis/github.com/just3ws/ccs/<timestamp>/`.

---

## 5. Indexing into the Brain
Once the artifacts are generated, ingest them into the Brain:

```bash
# Ingest all analysis artifacts for this repository
zdots-ctx ingest ~/my/analysis/github.com/just3ws/ccs/
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
