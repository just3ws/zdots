package capabilities

import "testing"

func TestBuildServiceSurface(t *testing.T) {
	t.Run("distinguishes mode=none from server-stopped", func(t *testing.T) {
		s := buildServiceSurface(surfaceInputs{
			ServiceAI:     "llama-cpp",
			AIMode:        "none",
			AIEndpoint:    "http://127.0.0.1:11500",
			EmbedEndpoint: "http://127.0.0.1:11501",
			HasColima:     true,
			Colima:        colimaStatus{Healthy: false, Socket: "/tmp/docker.sock"},
		})
		if s.SchemaVersion != "zdots.surface.v1" {
			t.Fatalf("schema_version = %q, want zdots.surface.v1", s.SchemaVersion)
		}
		if got := s.Services["inference"]; got.Status != "disabled" || got.Reason != "ZDOTS_AI_MODE=none" {
			t.Fatalf("inference = %+v, want disabled/ZDOTS_AI_MODE=none", got)
		}
		if got := s.Services["embeddings"]; got.Status != "disabled" || got.Reason != "ZDOTS_AI_MODE=none" {
			t.Fatalf("embeddings = %+v, want disabled/ZDOTS_AI_MODE=none", got)
		}
		if got := s.Services["colima"]; got.Status != "stopped" || got.DockerHost != "unix:///tmp/docker.sock" {
			t.Fatalf("colima = %+v, want stopped with unix:// docker_host", got)
		}
	})

	t.Run("reports ready when probes pass", func(t *testing.T) {
		s := buildServiceSurface(surfaceInputs{
			ServiceAI:     "llama-cpp",
			AIMode:        "local",
			AIModel:       "qwen3-8b",
			AIEndpoint:    "http://127.0.0.1:11500",
			AILive:        true,
			EmbedEndpoint: "http://127.0.0.1:11501",
			EmbedLive:     true,
			O2Endpoint:    "http://127.0.0.1:5080",
			O2Live:        true,
			JaegerURL:     "http://127.0.0.1:16686",
			JaegerLive:    true,
			CtxLive:       true,
			CtxDB:         "my",
			HasColima:     true,
			Colima:        colimaStatus{Healthy: true, Socket: "/tmp/docker.sock"},
		})
		for _, k := range []string{"inference", "embeddings", "openobserve", "jaeger", "knowledge", "colima"} {
			if got := s.Services[k].Status; got != "ready" {
				t.Fatalf("service %s status = %q, want ready", k, got)
			}
		}
	})
}
