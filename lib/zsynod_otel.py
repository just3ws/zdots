import os
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.resources import Resource

def setup_otel(service_name="zsynod-py"):
    """
    Configures OpenTelemetry to export spans to the local collector.
    Honors OTEL_EXPORTER_OTLP_ENDPOINT if set, defaults to localhost:4318.
    """
    endpoint = os.environ.get("OTEL_EXPORTER_OTLP_ENDPOINT", "http://127.0.0.1:4318")
    
    # Ensure the endpoint includes the correct path for the OTLP/HTTP exporter
    if not endpoint.endswith("/v1/traces"):
        endpoint = f"{endpoint.rstrip('/')}/v1/traces"

    resource = Resource.create({"service.name": service_name})
    provider = TracerProvider(resource=resource)
    
    exporter = OTLPSpanExporter(endpoint=endpoint)
    processor = BatchSpanProcessor(exporter)
    provider.add_span_processor(processor)
    
    trace.set_tracer_provider(provider)
    return trace.get_tracer(service_name)

# Usage in zsynod-py:
# tracer = setup_otel()
# with tracer.start_as_current_span("deliberation_tick") as span:
#     span.set_attribute("zsynod.round", 123)
#     ...
