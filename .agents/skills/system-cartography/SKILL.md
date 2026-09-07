---
name: system-cartography
description: Map, visualize, and audit the system's architectural topology, relational graph, database consistency, and bounded contexts across Rails and platform applications using Rails ERD, AnnotateRb, Graphviz, and Mermaid.
metadata:
  version: 1.0.0
---

# System Cartography & Schema Topology

System Cartography is the discipline of mapping the empirical terrain of data models, relationships, and persistence guarantees across the platform.

It bridges kinetic operational execution and empirical observation by maintaining living schema diagrams, top-of-file Markdown model headers, and bounded-context maps.

---

## 1. Core Principles

1. **Map Reality, Not Aspirations**:
   The database schema is the ultimate ground truth. Cartography reflects actual foreign keys, constraints, nullability, and tables in the database.

2. **Top-of-File Markdown Annotations (`head` insight)**:
   Every data model file begins with a GitHub Markdown table detailing columns, types, defaults, and indexes right after the magic comment. Any operator or agent running `head -n 25 app/models/foo.rb` gains instantaneous structural context without database roundtrips.

3. **Multi-Format Visual Artifacts**:
   - `erd.svg`: Scalable vector panoramic view for interactive browser zooming.
   - `erd.pdf`: Printable/exportable vector document.
   - `erd.png`: High-density raster overview.
   - `erd.mmd`: Raw Mermaid diagram definition for GitHub/IDE previews.
   - Bounded-context sliced diagrams in `docs/architecture/diagrams/`.

4. **Decompose into Bounded Contexts**:
   Monolithic schema diagrams obscure subsystem seams. Cartography maintains both full panoramic diagrams and isolated bounded-context maps.

---

## 2. Standard Workflows by Application

### WWWorkRemote (`~/github.com/wwworkremote/core`)
```bash
# Full + bounded-context diagrams
RAILS_ENV=development bundle exec rake diagrams:all

# Top-of-file Markdown annotations
RAILS_ENV=development bundle exec annotaterb models

# Audit ActiveRecord vs PostgreSQL constraint drift
RAILS_ENV=development bundle exec database_consistency
```

### Context Engine (`~/my/context-engine`)
```bash
# Full + bounded-context diagrams (Policy, Inbox/Knowledge, Media)
RAILS_ENV=development bundle exec rake diagrams:all

# Annotate Sequel models & specs with Markdown tables
RAILS_ENV=development bundle exec rake annotate:models
```

### Hallway (`~/github.com/just3ws/hallway`)
```bash
# Full + bounded-context diagrams (Community/Rooms, Milestones)
RAILS_ENV=development bundle exec rake diagrams:all

# Annotate ActiveRecord models & tests with Markdown tables
RAILS_ENV=development bundle exec annotaterb models

# Database consistency check
RAILS_ENV=development bundle exec database_consistency
```

---

## 3. System Map Documentation

Each application maintains its architectural topology in `docs/architecture/system-map.md`, covering:
- Visual cartography index with diagram links.
- Bounded-context domain breakdown and invariants.
- High-in-degree / high-out-degree hub models (gravity wells).
- Maintenance and regeneration CLI commands.
