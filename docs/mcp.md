HackTUI MCP

Start the server:

  ./bin/hacktui-mcp

The launcher sources .env automatically, changes into the umbrella root, and runs the stdio MCP server via `mix hacktui.mcp`.

Quick smoke test:

  python3 - <<'PY'
  import json, subprocess

  proc = subprocess.Popen(
      ["./bin/hacktui-mcp"],
      stdin=subprocess.PIPE,
      stdout=subprocess.PIPE,
      text=False,
  )

  def call(msg):
      payload = json.dumps(msg).encode()
      proc.stdin.write(f"Content-Length: {len(payload)}\r\n\r\n".encode() + payload)
      proc.stdin.flush()

      headers = b""
      while b"\r\n\r\n" not in headers:
          headers += proc.stdout.read(1)

      length = int([line for line in headers.decode().split("\r\n") if line.lower().startswith("content-length")][0].split(":", 1)[1])
      body = proc.stdout.read(length)
      return json.loads(body)

  print(call({"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {}}))
  print(call({"jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": {}}))
  print(call({"jsonrpc": "2.0", "id": 3, "method": "shutdown", "params": {}}))
  proc.wait(timeout=5)
  PY

Example MCP client config:

{
  "mcpServers": {
    "hacktui": {
      "command": "/home/aylac/Projects/hacktui_hermes/bin/hacktui-mcp"
    }
  }
}
