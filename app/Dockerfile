# Minimal vLLM inference runtime image.
# We do NOT bake the model into the image - models are large (15GB+)
# and baking them in would make every rebuild slow and bloat the
# image registry. Model is pulled at container start instead.
FROM vllm/vllm-openai:latest

WORKDIR /app

# vLLM's OpenAI-compatible server port
EXPOSE 8000

ENTRYPOINT ["python3", "-m", "vllm.entrypoints.openai.api_server"]
