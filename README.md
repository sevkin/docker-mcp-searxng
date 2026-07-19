# docker-mcp-searxng

A Docker Compose setup that runs a private [SearXNG](https://github.com/searxng/searxng)
metasearch engine and exposes it to AI assistants through the
[mcp-searxng](https://github.com/ihor-sokoliuk/mcp-searxng) MCP server over HTTP.

## What it does

- **SearXNG** (`searxng_json` container) — a self-hosted metasearch engine built from
  the official image with JSON output format enabled, so results can be consumed
  programmatically.
- **mcp-searxng** (`mcp_searxng` container) — an MCP server that wraps the SearXNG
  instance and exposes web search as a tool over the MCP HTTP transport.

The two containers share an isolated bridge network; only the MCP HTTP port is
published, on localhost, so the search engine itself is not reachable from outside
the host.

## Components

| Service        | Image                            | Container name   | Notes                                  |
| -------------- | -------------------------------- | ---------------- | -------------------------------------- |
| `searxng`      | built from `Dockerfile`          | `searxng_json`   | JSON format enabled, port `8080`       |
| `mcp-searxng`  | `isokoliuk/mcp-searxng:latest`   | `mcp_searxng`    | HTTP transport on port `8088`          |

## Files

- `Dockerfile` — extends `searxng/searxng:latest` and patches its settings to enable
  the `json` output format.
- `docker-compose.yml` — defines both services on the `docker-mcp-searxng` network,
  with the MCP server bound to `127.0.0.1:8088`.
- `crush.json` — example Crush configuration that registers the MCP server over HTTP
  at `http://localhost:8088/mcp`.

## Usage

Build and start the stack:

```bash
docker compose up -d --build
```

Verify the MCP server is reachable:

```bash
curl -s http://localhost:8088/mcp
```

Connect an MCP-capable client to `http://localhost:8088/mcp`. For Crush, the
included `crush.json` already points at this endpoint:

```json
{
  "mcp": {
    "searxng-web-search": {
      "type": "http",
      "url": "http://localhost:8088/mcp"
    }
  }
}
```

## Configuration

Environment variables for the `mcp-searxng` service (set in `docker-compose.yml`):

- `SEARXNG_URL` — URL of the SearXNG instance (default `http://searxng:8080`).
- `MCP_HTTP_PORT` — port the MCP HTTP server listens on (default `8088`).
- `MCP_HTTP_HOST` — bind address (default `0.0.0.0`).

To expose the SearXNG web UI directly, uncomment the `ports` section under the
`searxng` service in `docker-compose.yml`:

```yaml
    ports:
      - "8080:8080"
```

Once published, port `8080` lets you use SearXNG on its own — either through its
built-in web UI in a browser, or by pointing MCP-capable tools such as
[Cherry Studio](https://github.com/CherryHQ/cherry-studio) directly at the instance
as a web search provider. This is independent of the MCP server on port `8088`, which
remains the integration path for AI assistants.

## Note on overlapping Crush tools

[Crush](https://github.com/charmbracelet/crush) provides built-in tools that overlap
with this MCP server's capabilities: `fetch` and `agentic_fetch` (web search and
page reading) and `download` (saving files). The private SearXNG MCP is useful when
you want a self-hosted, controllable search backend rather than relying on its
external fetch path.

