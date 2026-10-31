#!/usr/bin/env python3
"""Build a review-only Brewfile usage report from Atuin history."""

from __future__ import annotations

import argparse
import collections
import datetime as dt
import json
import os
from pathlib import Path
import re
import shlex
import sqlite3
import subprocess
import sys
from urllib.parse import quote


ROOT = Path(__file__).resolve().parents[1]
BREWFILE_GROUPS = {
    "common": [ROOT / "Brewfile.common"],
    "home": [ROOT / "Brewfile.common", ROOT / "Brewfile.home"],
    "work": [ROOT / "Brewfile.common", ROOT / "Brewfile.work"],
    "rails-modernization": [ROOT / "modules/rails-modernization/Brewfile"],
}
FORMULA_RE = re.compile(r"^\s*brew\s+['\"]([^'\"]+)['\"]")
ASSIGNMENT_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=.*$")
SHELL_PREFIXES = {"command", "env", "exec", "nice", "nohup", "sudo", "time"}
SHELL_SEPARATORS = {";", "&", "&&", "|", "||", "|&"}
OPERATIONAL_EXCEPTIONS = {
    "aider": "used through the `zaider` / `laid` shell wrappers",
    "colima": "CLI retained for on-demand Docker use; VM removed and login autostart disabled under the bare-metal local-work rule",
    "llama.cpp": "backs the active Qwen3-8B service and core AI query routes",
    "nginx": "root-managed reverse proxy for core and related-repo services; restart requires operator sudo",
    "opencode": "exposed through the `zopencode` shell wrapper",
}


def run(args: list[str], *, env: dict[str, str] | None = None) -> str:
    result = subprocess.run(args, check=True, text=True, capture_output=True, env=env)
    return result.stdout


def declarations(paths: list[Path]) -> list[str]:
    found: list[str] = []
    for path in paths:
        for line in path.read_text(encoding="utf-8").splitlines():
            line = line.split("#", 1)[0]
            match = FORMULA_RE.match(line)
            if match:
                found.append(match.group(1))
    return list(dict.fromkeys(found))


def formula_prefix(spec: str, opt_root: Path) -> Path | None:
    """Resolve Homebrew aliases (e.g. python, whisper-cpp) through opt links."""
    candidate = opt_root / Path(spec).name
    if not candidate.exists():
        return None
    resolved = candidate.resolve()
    if not resolved.is_dir() or resolved.parent.parent.name != "Cellar":
        return None
    return resolved


def executables(prefix: Path) -> list[str]:
    names: set[str] = set()
    for relative in ("bin", "sbin", "libexec/bin"):
        directory = prefix / relative
        if not directory.is_dir():
            continue
        for path in directory.iterdir():
            try:
                if path.is_file() and os.access(path, os.X_OK):
                    names.add(path.name)
            except OSError:
                continue
    return sorted(names)


def command_heads(command: str) -> list[str]:
    """Extract top-level command heads without displaying/storing command text."""
    lexer = shlex.shlex(command, posix=True, punctuation_chars=";&|")
    lexer.whitespace_split = True
    lexer.commenters = ""
    segments: list[list[str]] = [[]]
    try:
        for token in lexer:
            if token in SHELL_SEPARATORS:
                segments.append([])
            else:
                segments[-1].append(token)
    except ValueError:
        # Malformed quoting makes this row unclassifiable; don't guess.
        return []

    heads: list[str] = []
    for words in segments:
        index = 0
        while index < len(words) and ASSIGNMENT_RE.match(words[index]):
            index += 1
        while index < len(words) and Path(words[index]).name in SHELL_PREFIXES:
            wrapper = Path(words[index]).name
            index += 1
            while index < len(words) and words[index].startswith("-"):
                flag = words[index]
                index += 1
                if wrapper in {"nice", "sudo"} and flag in {"-n", "-u", "-g", "-h", "-p", "-C"}:
                    if index < len(words):
                        index += 1
            while index < len(words) and ASSIGNMENT_RE.match(words[index]):
                index += 1
        if index < len(words):
            heads.append(Path(words[index]).name)
    return heads


def history_counts(path: Path, days: int) -> tuple[int, int, collections.Counter[str]]:
    uri = f"file:{quote(str(path))}?mode=ro"
    db = sqlite3.connect(uri, uri=True)
    try:
        maximum = db.execute(
            "SELECT COALESCE(MAX(timestamp), 0) FROM history WHERE deleted_at IS NULL"
        ).fetchone()[0]
        divisor = 1_000_000_000 if maximum > 10**15 else 1_000_000 if maximum > 10**12 else 1
        cutoff = int(dt.datetime.now(dt.timezone.utc).timestamp() - days * 86400) * divisor
        rows = db.execute(
            "SELECT command FROM history WHERE deleted_at IS NULL AND timestamp >= ?",
            (cutoff,),
        )
        counts: collections.Counter[str] = collections.Counter()
        row_count = 0
        for (command,) in rows:
            row_count += 1
            counts.update(command_heads(command))
        total = db.execute(
            "SELECT COUNT(*) FROM history WHERE deleted_at IS NULL"
        ).fetchone()[0]
        return row_count, total, counts
    finally:
        db.close()


def service_states() -> dict[str, str]:
    try:
        data = json.loads(run(["brew", "services", "list", "--json"], env={**os.environ, "HOMEBREW_NO_AUTO_UPDATE": "1"}))
    except (OSError, subprocess.CalledProcessError, json.JSONDecodeError):
        return {}
    return {item.get("name", ""): item.get("status", "unknown") for item in data}


def markdown_table(headers: list[str], rows: list[list[str]]) -> list[str]:
    out = ["| " + " | ".join(headers) + " |", "| " + " | ".join("---" for _ in headers) + " |"]
    out.extend("| " + " | ".join(cell.replace("|", "\\|") for cell in row) + " |" for row in rows)
    return out


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Map Brewfile formula executables to direct Atuin command use; produce review-only candidates."
    )
    parser.add_argument("--days", type=int, default=90, help="history window in days (default: 90)")
    parser.add_argument(
        "--history-db",
        type=Path,
        default=Path.home() / ".local/share/atuin/history.db",
        help="Atuin SQLite history database",
    )
    parser.add_argument(
        "--output",
        type=Path,
        help="report path (default: audit/brewfile-usage-YYYY-MM-DD.md)",
    )
    args = parser.parse_args()
    if args.days < 1:
        parser.error("--days must be greater than zero")
    if not args.history_db.is_file():
        parser.error(f"Atuin history database not found: {args.history_db}")

    try:
        brew_prefix = Path(run(["brew", "--prefix"]).strip())
        leaves = set(run(["brew", "leaves"]).splitlines())
        window_rows, total_rows, commands = history_counts(args.history_db, args.days)
    except (OSError, subprocess.CalledProcessError, sqlite3.Error) as exc:
        print(f"brewfile-usage: {exc}", file=sys.stderr)
        return 1

    profile_specs = {name: declarations(paths) for name, paths in BREWFILE_GROUPS.items()}
    all_specs = list(dict.fromkeys(spec for group in profile_specs.values() for spec in group))
    specs_by_formula: dict[str, set[str]] = collections.defaultdict(set)
    bins_by_spec: dict[str, list[str]] = {}
    installed_by_spec: dict[str, bool] = {}
    for spec in all_specs:
        prefix = formula_prefix(spec, brew_prefix / "opt")
        installed_by_spec[spec] = prefix is not None
        if prefix is None:
            bins_by_spec[spec] = []
            continue
        actual = prefix.parent.name
        specs_by_formula[actual].add(spec)
        bins_by_spec[spec] = executables(prefix)

    profiles_by_spec: dict[str, list[str]] = collections.defaultdict(list)
    for profile, specs in profile_specs.items():
        for spec in specs:
            profiles_by_spec[spec].append(profile)

    binaries_to_specs: dict[str, set[str]] = collections.defaultdict(set)
    hits_by_spec: dict[str, int] = collections.defaultdict(int)
    for spec, bins in bins_by_spec.items():
        if not installed_by_spec[spec]:
            continue
        for binary in bins:
            binaries_to_specs[binary].add(spec)
    for binary, count in commands.items():
        for spec in binaries_to_specs.get(binary, set()):
            hits_by_spec[spec] += count

    services = service_states()
    candidates: list[list[str]] = []
    formula_rows: list[list[str]] = []
    not_installed: list[list[str]] = []
    no_cli: list[list[str]] = []
    for spec in all_specs:
        profiles = ", ".join(profiles_by_spec[spec])
        if not installed_by_spec[spec]:
            not_installed.append([spec, profiles])
            continue
        bins = bins_by_spec[spec]
        display_bins = ", ".join(bins) if bins else "(no executable in bin/sbin/libexec/bin)"
        actual_name = formula_prefix(spec, brew_prefix / "opt").parent.name  # type: ignore[union-attr]
        state = services.get(actual_name, "")
        if not bins:
            no_cli.append([spec, profiles, state or "library/data/service package"])
            formula_rows.append([spec, profiles, display_bins, "—", state or "no CLI binary"])
            continue
        count = hits_by_spec[spec]
        status = f"brew service: {state}" if state and state != "none" else ""
        operational_note = OPERATIONAL_EXCEPTIONS.get(actual_name)
        if operational_note:
            status = f"operational: {operational_note}"
        formula_rows.append([spec, profiles, display_bins, str(count), status])
        if count == 0 and state != "started" and not operational_note:
            candidates.append([spec, profiles, display_bins])

    candidates.sort(key=lambda row: (row[0].casefold(), row[0]))
    formula_rows.sort(key=lambda row: (row[0].casefold(), row[0]))
    out = [
        f"# Brewfile Usage Audit — {dt.date.today().isoformat()}",
        "",
        f"Review-only report for a rolling {args.days}-day Atuin history window.",
        "",
        "## Method",
        "",
        f"- Read Atuin history from `{args.history_db}` using SQLite read-only mode.",
        f"- Queried {window_rows:,} non-deleted history rows in the window ({total_rows:,} total rows). Raw command strings, working directories, and session identifiers are never written to this report.",
        "- Mapped declared formulas through Homebrew `opt` links (including aliases) to executable files under each installed formula’s `bin`, `sbin`, and `libexec/bin` directories.",
        "- Counted top-level command invocations by executable basename. Shared executable names count as use for every provider. Shell aliases/functions and background/service use can be missed; zero-use rows are review candidates, never uninstall instructions.",
        "- Casks are not evaluated by shell history. Work-only formulae not installed on this host are listed separately, not treated as zero-use candidates.",
        "",
        "## Summary",
        "",
        f"- Installed Homebrew leaves: {len(leaves)}.",
        f"- Declared formulas across common, home, work, and optional Rails profiles: {len(all_specs)}.",
        f"- Installed declared formulas with executable files: {sum(1 for spec in all_specs if installed_by_spec[spec] and bins_by_spec[spec])}.",
        f"- Review candidates with no direct invocation in this window: {len(candidates)}.",
        f"- Declared formulas not installed on this host: {len(not_installed)}.",
        f"- Installed formulas without a CLI binary in scanned directories: {len(no_cli)}.",
        "",
        "## Operational exceptions",
        "",
        "- `nginx` is a root-managed local reverse proxy. Its live server blocks route `zdots.localhost`, `my.localhost`, `o2.localhost`, Hister, Gemstash, media-pipeline, Jaeger, and related application endpoints. It is core platform plumbing even if its command is absent from Atuin history; restarting it requires operator `sudo` and is outside this audit.",
        "- Local execution policy is bare metal. Dockerfiles remain valid for remote Fly deployments; local container runtimes and `act` are review candidates unless an explicit local workflow still requires them.",
        "- The Docker CLI may still be useful for remote build/deploy tooling, but its presence alone does not justify a local VM or container runtime.",
        "- Homebrew services marked `started` are excluded from zero-use candidates.",
        "- Platform and repo-wrapper exceptions are excluded even when Atuin records the wrapper name instead of the Homebrew executable.",
        "",
        "## Review candidates",
        "",
    ]
    if candidates:
        out.extend(markdown_table(["Formula", "Profile(s)", "Provided executable names"], candidates))
        out += ["", "Review each candidate against repo workflows, Nginx routes, service state, aliases, and related platform repositories before any removal."]
    else:
        out.append("No installed formulae met the zero-direct-invocation candidate rule.")
    out += ["", "## Declared but not installed", ""]
    if not_installed:
        out.extend(markdown_table(["Formula", "Profile(s)"], sorted(not_installed)))
    else:
        out.append("None.")
    out += ["", "## Installed formula mapping", ""]
    out.extend(markdown_table(["Formula spec", "Profile(s)", "Provided executables", "Direct calls", "Service state"], formula_rows))
    out += ["", "## Installed packages without CLI executables", ""]
    if no_cli:
        out.extend(markdown_table(["Formula", "Profile(s)", "Classification"], sorted(no_cli)))
    else:
        out.append("None.")
    out += ["", "## Profile scope", "", "The work profile intentionally includes corporate VPN, AWS, and EKS tooling. Its missing packages on the home host are not installation recommendations. The Rails modernization Brewfile is optional and explicitly limited to legacy analysis; an unsatisfied optional dependency is not a home-profile defect.", ""]

    output = args.output or ROOT / "audit" / f"brewfile-usage-{dt.date.today().isoformat()}.md"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("\n".join(out), encoding="utf-8")
    print(f"Wrote review-only Brewfile usage report: {output}")
    print(f"Window: {args.days} days; rows: {window_rows:,}; candidates: {len(candidates)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
