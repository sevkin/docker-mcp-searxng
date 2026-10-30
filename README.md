# docker-mcp-searxng

A Docker Compose setup that runs a private [SearXNG](https://github.com/searxng/searxng)
metasearch engine and exposes it to AI assistants through the
[mcp-searxng](https://github.com/ihor-sokoliuk/mcp-searxng) MCP server over HTTP.

## What it does

- **SearXNG** (`searxng_json` container) — a self-hosted metasearch engine built
  from the pinned official `searxng/searxng` image. The build patches the settings
  template used by the entrypoint, enabling JSON output and selecting the engine set,
  so results can be consumed programmatically.
- **mcp-searxng** (`mcp_searxng` container) — an MCP server that wraps the SearXNG
  instance and exposes web search as a tool over the MCP HTTP transport.

The two containers share an isolated bridge network; only the MCP HTTP port is
published, on localhost, so the search engine itself is not reachable from outside
the host.

## Components

| Service        | Image                                          | Container name   | Notes                             |
| -------------- | ---------------------------------------------- | ---------------- | --------------------------------- |
| `searxng`      | built from `Dockerfile` (`searxng/searxng:2026.5.31-7159b8aed`) | `searxng_json`   | JSON enabled, port `8080`         |
| `mcp-searxng`  | `isokoliuk/mcp-searxng:latest`                 | `mcp_searxng`    | HTTP transport on port `28088`    |

## Files

- `Dockerfile` — builds on the pinned upstream image and patches its settings
  template before the container's first start: JSON output is enabled and the engine
  list is adjusted (`bing`, `seznam`, `mwmbl`, `wiby` enabled; `google`, `brave`,
  `duckduckgo`, `startpage` disabled because they answer this host with CAPTCHAs,
  rate limits, or empty result pages). The engine list is a snapshot of what worked
  on 2026-10-30 — availability changes, so adjust it and rebuild when needed.
  Because the template is patched rather than replaced, the entrypoint still
  generates `/etc/searxng/settings.yml` with a random `server.secret_key`.
- `docker-compose.yml` — defines both services on the `docker-mcp-searxng` network,
  with the MCP server bound to `127.0.0.1:28088`.
- `crush.json` — example Crush configuration that registers the MCP server over HTTP
  at `http://localhost:28088/mcp`.

## Usage

Build and start the stack:

```bash
docker compose up -d --build
```

Verify the MCP server is reachable:

```bash
curl -s http://localhost:28088/mcp
```

Connect an MCP-capable client to `http://localhost:28088/mcp`. For Crush, the
included `crush.json` already points at this endpoint:

```json
{
  "mcp": {
    "searxng-web-search": {
      "type": "http",
      "url": "http://localhost:28088/mcp"
    }
  }
}
```

## Updating

The base image is pinned in the `Dockerfile` and the built image is tagged in
`docker-compose.yml`. To upgrade, set both to the same newer release (tags look like
`YYYY.M.D-<hash>`), then rebuild and recreate:

```bash
docker compose build --pull
docker compose up -d --renew-anon-volumes
```

`--renew-anon-volumes` matters: `/etc/searxng` is an anonymous volume declared by the
image, and the entrypoint only generates `settings.yml` when the file is missing.
Without it, a rebuilt image can keep serving the previously generated settings.

The same applies after editing the engine lists in the `Dockerfile`. After any
change, re-check which engines are actually enabled (the engine publishes no host
port, so ask it from inside the container):

```bash
docker exec searxng_json wget -qO- http://127.0.0.1:8080/config \
  | python3 -c 'import json,sys; d=json.load(sys.stdin); print([e["name"] for e in d["engines"] if "general" in e.get("categories",[]) and e.get("enabled")])'
```

## Configuration

Environment variables for the `mcp-searxng` service (set in `docker-compose.yml`):

- `SEARXNG_URL` — URL of the SearXNG instance (default `http://searxng:8080`).
- `MCP_HTTP_PORT` — port the MCP HTTP server listens on (`28088`; the same port is
  published on loopback).
- `MCP_HTTP_HOST` — bind address (default `0.0.0.0`).

To move the MCP endpoint, change `MCP_HTTP_PORT` and the `ports` mapping together,
recreate the container, and update the client URL.

SearXNG publishes no host port: it is reachable only from the other container. To
browse its web UI or run a direct `/config` check, add a temporary loopback mapping
under the `searxng` service:

```yaml
    ports:
      - "127.0.0.1:8080:8080"
```

Publishing it also lets MCP-capable tools such as
[Cherry Studio](https://github.com/CherryHQ/cherry-studio) query the instance
directly as a web search provider, without going through mcp-searxng.

## Note on overlapping Crush tools

[Crush](https://github.com/charmbracelet/crush) provides built-in tools that overlap
with this MCP server's capabilities: `fetch` and `agentic_fetch` (web search and
page reading) and `download` (saving files). The private SearXNG MCP is useful when
you want a self-hosted, controllable search backend rather than relying on its
external fetch path.

