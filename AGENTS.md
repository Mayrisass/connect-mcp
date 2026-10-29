# Running this repo in the Base44 sandbox

This is a library + HTTP MCP server, not a web UI. `docker-compose.base44.yml`
runs it locally; there is no page to render at `/`.

## Stack

- `mcp` — `node:22` image built from `Dockerfile`. Dependencies (`npm ci`, plus
  `tsx` installed `--no-save`) are installed at **image build time** into
  `/opt/deps`, never at container start. The source is bind-mounted at
  `/workspace` and started with `tsx watch src/index-http.ts`, so edits reload.
- `web` — nginx on host port 3000, the preview entry point.

## Non-obvious quirks

- **Host validation, twice.** `src/http.ts` passes
  `allowedHosts: ['mcp.connect.quid.li', 'localhost']` to the MCP SDK, and
  `src/request-host.ts` resolves the host from `X-Forwarded-Host` *before*
  `Host`. The preview proxy sends its own hostname, so `nginx.base44.conf`
  rewrites `Host: localhost` and blank-sets `X-Forwarded-Host` (an empty
  `proxy_set_header` value removes the header). Without this every request 403s.
- **Healthchecks must send an allowed host.** A probe to
  `http://127.0.0.1:8080/health` fails with 403 because the Host is
  `127.0.0.1:8080`. The compose healthcheck uses `node:http` with
  `headers: { Host: 'localhost' }`.
- **`node_modules` is a named volume.** The bind mount would otherwise hide the
  image's dependencies; the start command copies `/opt/deps/node_modules` into
  the volume once (stamped, re-seeded when `package-lock.json` changes).

## Verify

```bash
docker compose -f docker-compose.base44.yml ps          # both healthy
curl -s localhost:3000/health                           # {"ok":true,...}
curl -s -X POST localhost:3000/ -H 'Content-Type: application/json' \
  -H 'Accept: application/json, text/event-stream' \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"smoke","version":"1"}}}'
```

No environment secrets are required. `CONNECT_MCP_ALLOW_ANONYMOUS=1` enables
keyless tool calls on the shared anonymous quota; a Connect API key is supplied
per request via the `x-api-key` header, not an env var.

Tests run inside the container (the sandbox host has no Node):
`docker compose -f docker-compose.base44.yml exec -T mcp ./node_modules/.bin/vitest run`
