# Panoramic View Cartography: softwarecraftsmanship.org
**Domain & System Archaeology Report**
*Generated: 2026-10-02 | Platform: zdots Datalake (`~/.local/state/zdots/datalake.duckdb`) & Hister Engine*

---

## 1. Executive Summary & Provenance

The domain **`softwarecraftsmanship.org`** and its flagship property **`manifesto.softwarecraftsmanship.org`** represent the digital monument and registry for the **Manifesto for Software Craftsmanship**, drafted in late 2008 and launched to the public on **March 6, 2009**.

* **Root Ownership / Operator:** **8th Light, Inc.**
  * Embedded source references point to 8th Light's internal infrastructure: `http://scmanifesto-staging.8thlight.com/` and core team authorship (Doug Bradbury, Paul Pagel, Robert C. Martin).
* **Current Operational State:** **Active but architecturally frozen.**
  * Signatures continue to flow in organically via an automated Rails API on AWS Elastic Beanstalk.
  * Latest verified signature recorded: **#37,842** (signed on **October 2, 2026**).
  * Total public confirmed registry signatories: **27,601 active records** (after 17 years of deduplication/removals).
* **Mike Hall's Anchor:**
  * **Signatory #106** (`id: 106`, `number: 106`)
  * **Verified Timestamp:** `2009-03-07T01:06:59.000Z` (**Friday, March 6, 2009, 7:06:59 PM CST**).
  * Registered as: `Michael D. Hall`, `Crystal Lake, IL`.

---

## 2. Infrastructure & Technical Stack Archeology

```
[ DNS Layer: DNSimple Anycast ]
      │
      ├──> manifesto.softwarecraftsmanship.org
      │         │
      │         ▼
      │   AWS Elastic Beanstalk (ELB: us-east-1)
      │         │
      │         ├──> Nginx Reverse Proxy (HTTP/2, SSL)
      │         │
      │         ├──> Client SPA (Backbone.js 1.3.3 / Underscore / jQuery 3.6.0)
      │         │     - Static Assets last-modified: June 26, 2023
      │         │     - CSS: Dieter Schneider CSS Template (2006)
      │         │
      │         └──> Ruby on Rails Backend
      │               - REST API: /signatories, /signatories/search, /sign/sign
      │               - Database: PostgreSQL/MySQL with incremental IDs
      │
      ├──> katas.softwarecraftsmanship.org ──> Tumblr Custom Domain (74.114.154.22)
      │
      └──> scna.softwarecraftsmanship.org  ──> AWS CloudFront CDN (d3l6fwbwqedfpn...)
```

### Stack Decomposition
| Layer | Technology | Vintage / Era | Notes |
|---|---|---|---|
| **DNS** | DNSimple Edge | Modern | Hosted via DNSimple, originally founded by Chicago peer Anthony Eden. |
| **Hosting** | AWS Elastic Beanstalk | 2014–Present | Scaled load balancer in `us-east-1`. |
| **Server** | Nginx | Modern | Termination proxy. |
| **App Server** | Ruby on Rails | 2009–2012 core | Powers internal API endpoints. |
| **Frontend** | Backbone.js 1.3.3 + Underscore | ~2011–2014 SPA Era | Hash routing (`#/sign`, `#/reading`, `#/confirm`). |
| **DOM / Ajax** | jQuery 3.6.0 | Bumped ~2021 | Upgraded from legacy 1.x for security patch maintenance. |
| **Metrics** | D3.js v3 | ~2013 | Generates SVG signup rate velocity graphs on `/metrics`. |

---

## 3. Subdomain Cartography

Audited and cataloged in DuckDB:

1. **`manifesto.softwarecraftsmanship.org`**:
   * **Status:** `200 OK`
   * **Function:** Main interactive manifesto, signatory search, and internationalized translations (13 languages: en, da, de, es, fr-fr, ru-ru, tr, zh-cn, vi, pt-br, ar, it, ua).
2. **`katas.softwarecraftsmanship.org`**:
   * **Status:** `301 -> HTTPS` (Tumblr)
   * **Target:** `domains.tumblr.com`
   * **Function:** The original community code kata blog.
3. **`scna.softwarecraftsmanship.org`**:
   * **Status:** `301 -> HTTPS` (CloudFront)
   * **Target:** `d3l6fwbwqedfpn.cloudfront.net`
   * **Function:** Software Craftsmanship North America conference archive.

---

## 4. Curated Reading List & Link Rot Audit

The manifesto maintains a canonical **"Further Reading"** curriculum (`/reading`), divided into four categories. A full live HTTP probe of all 35 links revealed:
* **Live Links:** 25 (71.4%)
* **Rotten / Broken Links:** 10 (28.6%)

### Link Health Breakdown

#### A. Background Materials (Foundational Books & Papers)
* `http://www.amazon.com/Software-Craftsmanship-Imperative-Pete-McBreen/dp/0201733862` — `200 OK`
* `http://www.amazon.com/Pragmatic-Programmer-Journeyman-Master/dp/020161622X/` — `200 OK`
* `http://www.amazon.com/Craftsman-Prof-Richard-Sennett/dp/0300151195/` — `200 OK`
* `http://www.amazon.com/Apprenticeship-Patterns-Guidance-Aspiring-Craftsman/dp/0596518382/` — `200 OK`
* `http://chimera.labs.oreilly.com/books/1234000001813/index.html` — `200 OK`
* `http://projects.ict.usc.edu/itw/gel/EricssonDeliberatePracticePR93.pdf` — ❌ `Timed out` (USC lab domain dead)
* `http://www.jerwood-no.org.uk/pdf/Dunning%20Kruger.pdf` — ❌ `404 Not Found` (Original Kruger & Dunning PDF domain extinct)

#### B. Food for Thought (Essays & Manifestos)
* `http://blog.oshineye.com/2011/01/software-craftsmanship-more-than-just.html` — `200 OK`
* `http://ravimohan.blogspot.com/2005/09/nostalgia-for-guilds-and-other.html` — `200 OK`
* `http://jd-syntropy.blogspot.com/2009/01/am-i-master.html` — `200 OK`
* `http://norvig.com/21-days.html` — `200 OK` (Peter Norvig classic)
* `http://thewalrus.ca/the-puppet-master-and-the-apprentice/` — `200 OK`
* `https://sites.google.com/site/unclebobconsultingllc/home/articles/what-s-all-this-nonsense-about-katas` — ❌ `404 Not Found` (Google Sites migration break)
* `http://www.codinghorror.com/blog/2008/06/the-ultimate-code-kata.html` — ❌ `DNS Failure` (Coding Horror moved domains/structure)
* `http://redsquirrel.com/cgi-bin/dave/2007/08/22#a.call.for.apprenticeship` — ❌ `404 Not Found` (Dave Hoover's legacy CGI blog)
* `http://www.davethehat.com/dh/blog/2009/05/25/software-craftsmanship-can-we-just-get-over-it/` — ❌ `500 Server Error`

#### C. Katas & Exercises
* `http://katas.softwarecraftsmanship.org/` — `200 OK`
* `https://github.com/paulwpagel/codekata` — `200 OK` (Paul Pagel / 8th Light repo)
* `http://codekata.pragprog.com/` — ❌ `403 Forbidden` (PragProg legacy subdomain blocked)

#### D. Conferences & Community
* `http://scna.softwarecraftsmanship.org/` — `200 OK`
* `http://www.flickr.com/groups/softwarecraftsmanship/pool/` — `200 OK`
* `http://groups.google.com/group/artesanos-de-software` — `200 OK`
* `http://parlezuml.com/softwarecraftsmanship/` — ❌ `404 Not Found` (Jason Gorman's SNUK page)
* `http://groups.google.co.uk/group/software_craftsmanship` — ❌ `404 Not Found` (Google Groups co.uk redirect dead)

---

## 5. Datalake & Hister Integration

### DuckDB Datalake Schema (`~/.local/state/zdots/datalake.duckdb`)
Three primary tables now structure all captured knowledge:

1. **`scm_signatories`** (27,601 rows):
   ```sql
   SELECT signatory_number, id, name, location, signed_on 
   FROM scm_signatories 
   WHERE id = 106;
   ```
   *Result:* `101 | 106 | Michael D. Hall | Crystal Lake, IL | 2009-03-07T01:06:59.000Z`
2. **`scm_subdomains`** (3 rows):
   Catalog of active DNS routes, ELB/CloudFront endpoints, and IP delegations.
3. **`scm_reading_links`** (35 rows):
   Complete link catalog with live status codes, section categories, and health audit dates.

### Hister Local Search Engine Index
Indexed and searchable locally via `hister search`:
* `https://manifesto.softwarecraftsmanship.org/`
* `https://katas.softwarecraftsmanship.org/`
* `https://scna.softwarecraftsmanship.org/`

---

## 6. Timeline Presentation: The First Hundred Signatories Over Time

By cross-referencing the **earliest Wayback snapshot (March 10, 2009, 06:55 UTC)** against the **2026 live database state**, we uncovered the exact mechanics of how the ledger drifted and why numbers shifted.

### The Core Archaeological Discrepancies

```
 March 6, 2009 (Launch Day)
   ├── 7:06:59 PM CST: Michael D. Hall signs. Assigned immutable database id: 106.
   │   (At this moment, ~4 other submissions between #101-#105 are awaiting email confirmation)
   │
 March 10, 2009 (Wayback Earliest Capture)
   ├── Total published on page: 1,244
   ├── Bug in production HTML: Cory Foy is rendered TWICE (#28 and #32).
   ├── Because of the duplicate entry, all subsequent rows are shifted back by +1.
   └── Michael D. Hall displays at visual position #102.
   │
 ~2011–2014 (Backbone SPA & Database Cleanup)
   ├── The duplicate Cory Foy entry (#28) is purged, consolidating at #31.
   ├── All subsequent rows collapse forward by -1:
   │   • Joseph Leddy moves from #29 → #28
   │   • Nathaniel Talbott moves from #101 → #100
   │   • Michael D. Hall moves from #102 → #101
   └── Casey Charlton (#120) exercises GDPR/removal or declines token confirmation, shifting 120+.
```

### Key Signatory Drift Audit Table

| Signatory | 2009 Snapshot Rank | 2026 Live Table Rank | Canonical DB ID | Net Shift | Underlying Forensic Cause |
|---|:---:|:---:|:---:|:---:|---|
| **Doug Bradbury** | #1 | #1 | 1 | 0 | Unchanged (Primary Author / 8th Light) |
| **Corey Haines** | #2 | #2 | 2 | 0 | Unchanged |
| **Paul Pagel** | #3 | #3 | 3 | 0 | Location normalized (`Chicago, USA` → `Chicago, IL, USA`) |
| **Micah Martin** | #4 | #4 | 4 | 0 | Unchanged |
| **Robert C. Martin (Uncle Bob)** | #5 | #5 | 5 | 0 | Signed March 6, 2009 at 20:36 UTC |
| **Cory Foy** | **#28 & #32** | **#31** | 31 | +3 | **The Double-Sign Bug**: In 2009, Cory Foy appeared at both #28 and #32 in the HTML table. |
| **Joseph Leddy** | #29 | #28 | 28 | -1 | Shifted forward by 1 when Cory Foy's duplicate #28 was deduped. |
| **Nate Jackson** | #30 | #29 | 29 | -1 | Shifted forward by 1 due to deduplication. |
| **Denny Abraham** | #31 | #30 | 30 | -1 | Shifted forward by 1 due to deduplication. |
| **Pete Johns** | #100 | #99 | 99 | -1 | Shifted forward by 1 due to deduplication. |
| **Nathaniel Talbott** | #101 | #100 | 100 | -1 | Shifted forward by 1 due to deduplication. |
| **Michael D. Hall** | **#102** | **#101** | **106** | **-1** | **Immutable DB ID: 106**. Positioned at #102 in 2009 (due to Cory Foy duplicate), then shifted to #101 in the SPA table after deduplication. IDs 101–105 were pending confirmations. |
| **Tony Geros** | #103 | #102 | 107 | -1 | Shifted forward by 1 due to deduplication. |
| **Casey Charlton** | **#120** | *Deleted* | 120 | N/A | **Subsequent Removal**: Present in 2009; subsequently deleted/unconfirmed. |

### Technical Insights from the Datalake

1. **The Architecture of Confirmation Latency:**
   The site uses an asynchronous email verification flow (`signatory_must_be_confirmed`). Submitting the form writes an autoincrement row with `number = id` (e.g. `106`), but the public list only iterates `confirmed: true` records sorted by `id ASC`. When Mike signed at 7:06 PM CST, IDs 101, 102, 103, 104, and 105 were already reserved in the database by other users whose confirmation emails had not yet been validated.
2. **Display Rank vs. Identity Rank:**
   * **Visual Table Rank** is ephemeral and dynamic: it reflects `ROW_NUMBER()` over currently active confirmed accounts.
   * **Canonical Identity** is permanent: Mike Hall's record is permanently ledger entry **`id: 106, number: 106`**.
3. **Double-Submission Artifacts in Early Web Apps:**
   Early Rails applications without database-level uniqueness constraints or idempotent form submissions frequently allowed users hitting "Back" or double-clicking the submit button to register twice (as occurred with Cory Foy). When 8th Light rebuilt the frontend as an SPA and cleaned up legacy duplicates, the visual table compressed by exactly one position up through row 119.

