module zdots/cmd/zdots-secret-scan

go 1.26

require (
	gopkg.in/yaml.v3 v3.0.1
	zdots/pkg/re2registry v0.0.0
)

// Shared RE2 engine lives in-repo; resolved by relative path (no published module).
replace zdots/pkg/re2registry => ../../pkg/re2registry
