FROM searxng/searxng:latest

LABEL org.opencontainers.image.title="SearXNG with JSON output"
LABEL org.opencontainers.image.description="SearXNG metasearch engine with JSON format enabled"
LABEL org.opencontainers.image.source="https://github.com/searxng/searxng"
LABEL org.opencontainers.image.vendor="searxng"

RUN sed -i '/^  formats:/a\    - json' /usr/local/searxng/searx/settings.yml

