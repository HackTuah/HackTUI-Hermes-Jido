# HackTUI MCP stdio quickstart

Use the stable launcher below whenever you want Hermes or any other MCP client to connect to the HackTUI MCP server over stdio.

## Authoritative launcher

`/home/aylac/Projects/hacktui_hermes/bin/hacktui-mcp`

Why this launcher matters:
- exports `HACKTUI_MCP_STDIO=1`
- keeps JSON-RPC responses clean on stdout
- leaves warnings and logs on stderr
- avoids client-side framing failures caused by mixed stdout output

## Manual smoke test

From the repo root:

```bash
printf 'Content-Length: 52\r\n\r\n{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' \
  | /home/aylac/Projects/hacktui_hermes/bin/hacktui-mcp
```

Expected behavior:
- stdout contains a valid JSON-RPC initialize response
- stderr may contain compile warnings or other non-protocol diagnostics

## Hermes MCP client config

Example `~/.hermes/config.yaml` entry:

```yaml
mcp_servers:
  hacktui:
    command: "/home/aylac/Projects/hacktui_hermes/bin/hacktui-mcp"
    args: []
    connect_timeout: 60
    timeout: 180
```

After updating config, restart Hermes so it reconnects and re-discovers tools.

## Troubleshooting

If a client fails to parse responses:
- make sure it launches `bin/hacktui-mcp`, not `mix hacktui.mcp`
- do not remove `HACKTUI_MCP_STDIO=1`
- treat anything on stderr as diagnostics, not protocol traffic
