#!/usr/bin/env bats
# tests/theme_gen.bats — contract for zdots-theme-gen.
#
# WHAT: every surface theme artifact under assets/<scheme>/ is generated from a
# single palette source (etc/themes/<scheme>.yaml). WHY: theming used to be a
# ~15-file hand sweep with silent drift; the generator + this --check gate make
# the source authoritative. If a committed asset diverges from its source, this
# fails — catching hand-edits and stale palettes before they ship.

setup() {
  load "setup.bash"
  setup_environment
}

@test "theme-gen: kanagawa-wave surfaces are in sync with their source" {
  run ruby "$REPO_ROOT/libexec/zdots-theme-gen" kanagawa-wave --check
  [ "$status" -eq 0 ]
}

@test "theme-gen: --list includes kanagawa-wave" {
  run ruby "$REPO_ROOT/libexec/zdots-theme-gen" --list
  [ "$status" -eq 0 ]
  [[ "$output" == *"kanagawa-wave"* ]]
}

@test "theme-gen: kanagawa-lotus surfaces are in sync with their source" {
  run ruby "$REPO_ROOT/libexec/zdots-theme-gen" kanagawa-lotus --check
  [ "$status" -eq 0 ]
}

@test "theme-gen: lotus and wave name the same colours, so one template set serves both" {
  run ruby -ryaml -e 'w, l = %w[kanagawa-wave kanagawa-lotus].map { YAML.safe_load_file("#{ARGV[0]}/etc/themes/#{it}.yaml")["palette"].keys }; missing = w - l; abort(missing.join(" ")) unless missing.empty?' "$REPO_ROOT"
  [ "$status" -eq 0 ]
}
