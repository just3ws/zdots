package otel

import (
	"context"
	"os"
	"time"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/codes"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.25.0"
	"go.opentelemetry.io/otel/trace"
)

// TracerProvider holds an optional tracer. If nil, observability is disabled.
type TracerProvider struct {
	tracer trace.Tracer
	tp     *sdktrace.TracerProvider
}

// InitTracer initializes the global OTEL trace provider.
// If OTEL_EXPORTER_OTLP_ENDPOINT is not set or unreachable, returns a nil-tracer provider (graceful fallback).
func InitTracer(ctx context.Context) (*TracerProvider, error) {
	endpoint := os.Getenv("OTEL_EXPORTER_OTLP_ENDPOINT")
	if endpoint == "" {
		endpoint = "http://127.0.0.1:4317" // default OTel collector endpoint
	}

	// Create exporter with a short timeout for the initial connection check
	ctx, cancel := context.WithTimeout(ctx, 2*time.Second)
	defer cancel()

	exp, err := otlptracehttp.New(ctx, otlptracehttp.WithEndpoint(endpoint), otlptracehttp.WithInsecure())
	if err != nil {
		// Collector unreachable; return a no-op provider
		return &TracerProvider{tracer: nil}, nil
	}

	res, err := resource.New(ctx, resource.WithAttributes(
		semconv.ServiceName("zdots-phi-scrub"),
		semconv.ServiceVersion("1.0.0"),
	))
	if err != nil {
		return nil, err
	}

	tp := sdktrace.NewTracerProvider(
		sdktrace.WithBatcher(exp),
		sdktrace.WithResource(res),
	)
	otel.SetTracerProvider(tp)

	return &TracerProvider{
		tracer: tp.Tracer("zdots-phi-scrub"),
		tp:     tp,
	}, nil
}

// EmitSuppressMatch records an OTEL span for a suppress-flagged pattern match.
// No-op if tracer is nil.
func (tp *TracerProvider) EmitSuppressMatch(ctx context.Context, patternName string) {
	if tp == nil || tp.tracer == nil {
		return
	}

	ctx, span := tp.tracer.Start(ctx, "phi.suppress_match")
	defer span.End()

	span.SetStatus(codes.Error, "suppress-flagged pattern matched")
	span.SetAttributes(
		attribute.String("pattern.name", patternName),
		attribute.String("event", "suppress_match"),
	)
}

// Shutdown flushes any pending spans and shuts down the trace provider.
// No-op if provider is nil.
func (tp *TracerProvider) Shutdown(ctx context.Context) error {
	if tp == nil || tp.tp == nil {
		return nil
	}
	return tp.tp.Shutdown(ctx)
}

// Disabled returns true if observability is not initialized.
func (tp *TracerProvider) Disabled() bool {
	return tp == nil || tp.tracer == nil
}
