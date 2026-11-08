---
id: Z-359
title: Add a sourced lived-history photo timeline
status: In Progress
assignee: []
created_date: '2026-11-05T14:04:00Z'
updated_date: '2026-11-05T14:08:00Z'
labels: []
dependencies: []
references:
  - CONTEXT.md
  - _data/community_timeline.yml
  - timeline/community/index.html
  - /Users/mike/ai/inbox
documentation:
  - docs/style-guide-and-canonical-naming.md
priority: high
type: feature
ordinal: 230895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The community archive needs a browsable visual chronology that helps visitors connect real moments to the communities, teaching, work, and personal experiences behind Mike’s history. Google Photos exports contain date, location, and visual evidence, but some albums are duplicates, some include bystanders, workplace material, or personal identifiers, and not every album belongs on a public site.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A chronological website surface presents selected photo albums as dated historical moments with clear location and event context where supported.
- [ ] #2 Each public photo is an optimized local derivative with useful alt text and provenance; sensitive originals and metadata are not published.
- [ ] #3 Dates, locations, and narrative claims distinguish embedded metadata, album/file evidence, and Mike’s recollection.
- [ ] #4 The timeline links to existing community and archive pages and works at mobile and desktop widths.
- [ ] #5 The source ZIP albums remain unchanged and are not checked into the public repository.
- [ ] #6 The newly added EMR-Bear Onsite album and any private or identifying material remain unpublished pending a clear public-safety review.
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
## Context brief
- The existing community archive is data-driven by `_data/community_timeline.yml` and rendered at `timeline/community/index.html`; current event cards already carry chronology, locations, community tags, and source links.
- `bin/import-photo-album` imports shared Google Photos URLs only; it does not support local ZIP exports, so use direct, read-only ZIP inspection and create only reviewed derivative files.
- The inbox currently has 27 older ZIP albums plus a newly added 3.66 GB `EMR-Bear Onsite` ZIP. The two July 2010 SCMC ZIPs are visually overlapping but not byte-identical. Keep all ZIPs untouched and outside the repository.
- Several albums provide only dates from filenames/album titles; KubeCon photos have embedded date and GPS metadata. Public copy must identify the evidence basis and avoid implying EXIF when the date comes from naming or recollection.
- The SFOR album includes a service card with personal identifiers and Cantigny museum images about Brčko. Do not publish the card. OMF and EMR-Bear imagery may contain workplace/private material and remain out of public canon pending review.

## Implementation plan
1. Add a data-driven photo chronology that complements and links to the existing community timeline, ordered by event/capture date and allowing filters or era jumps.
2. Select a small representative set from community-event albums and the Cantigny exhibit; crop/resize and strip EXIF from public derivatives. Do not bulk-copy source albums or expose private work imagery.
3. Record dates, places, caption provenance, and evidence limitations in canonical data. Include Mike’s CCC logo contribution precisely: another person designed the logo; Mike helped select the submission, adapted the CCC shirt/sticker design, integrated it into the site, and recalls the shirt as popular.
4. Add the route to the existing archive navigation and preserve mobile/desktop readability.
5. Build, install through `bin/install-localhost`, inspect affected routes/assets, and review the exact changed files before committing only this task’s files.

Scope now includes clearly labeled personal-history moments beyond the technology-community thread because Mike added Bosnia/SFOR at Cantigny, the Chicago woodpecker rescue, and Weird Al/Emo Phillips as lived context. Keep categories distinct from career milestones; the SFOR service card and employer-private EMR-Bear materials stay unpublished.
<!-- SECTION:PLAN:END -->
