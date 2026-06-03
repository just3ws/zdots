#!/usr/bin/env bats
# tests/rails_modernization_module.bats - optional Rails modernization module

setup() {
  load "setup.bash"
  setup_environment
  MODULE="$REPO_ROOT/modules/rails-modernization"
  MODBIN="$MODULE/bin"
}

make_fake_rails_app() {
  mkdir -p "$BATS_TEST_TMPDIR/app/config"
  cat > "$BATS_TEST_TMPDIR/app/config/environment.rb" <<'RUBY'
Column = Struct.new(:name, :type)
Association = Struct.new(:name, :macro, :class_name)

class User
  def self.columns
    [
      Column.new("id", :integer),
      Column.new("email", :string)
    ]
  end

  def self.reflect_on_all_associations
    [
      Association.new(:orders, :has_many, "Order"),
      Association.new(:account, :belongs_to, "Account")
    ]
  end
end
RUBY
}

@test "rails module commands have --help contracts" {
  for command in zdots-archeologist zdots-archeologist-diagram zdots-archeologist-run zdots-ruby-legacy-setup; do
    run "$MODBIN/$command" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
  done
}

@test "zdots-archeologist loads config/environment from current Rails root" {
  make_fake_rails_app

  run bash -c "cd '$BATS_TEST_TMPDIR/app' && '$MODBIN/zdots-archeologist' User"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | jq -e '.model == "User"' >/dev/null
  printf '%s\n' "$output" | jq -e '.columns[0].name == "id"' >/dev/null
  printf '%s\n' "$output" | jq -e '.associations[0].name == "orders"' >/dev/null
}

@test "zdots-archeologist-diagram converts model JSON to Mermaid" {
  json="$BATS_TEST_TMPDIR/user.json"
  cat > "$json" <<'JSON'
{
  "model": "User",
  "columns": [{ "name": "id", "type": "integer" }],
  "associations": [{ "name": "orders", "macro": "has_many", "class_name": "Order" }]
}
JSON

  run "$MODBIN/zdots-archeologist-diagram" "$json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"erDiagram"* ]]
  [[ "$output" == *"User ||--o{ Order"* ]]
}

@test "zdots-archeologist-run writes artifacts under ZDOTS_MY_ROOT" {
  make_fake_rails_app
  mkdir -p "$BATS_TEST_TMPDIR/my"

  run bash -c "cd '$BATS_TEST_TMPDIR/app' && ZDOTS_MY_ROOT='$BATS_TEST_TMPDIR/my' '$MODBIN/zdots-archeologist-run' git@github.com:org/repo.git User"
  [ "$status" -eq 0 ]

  artifact_dir="$(find "$BATS_TEST_TMPDIR/my/analysis/github.com/org/repo" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
  [ -n "$artifact_dir" ]
  [ -s "$artifact_dir/User.json" ]
  [ -s "$artifact_dir/User.mmd" ]
  [ -s "$artifact_dir/User_report.md" ]
}
