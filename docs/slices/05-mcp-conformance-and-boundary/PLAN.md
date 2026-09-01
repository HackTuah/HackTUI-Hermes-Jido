# Slice 05 — mcp-conformance-and-boundary

**Branch:** `slice/05-mcp-conformance-and-boundary`
**Status:** in progress
**Depends on:** slice 04 (`671049b`)

> Renumbered: the original plan had 05 = data-integrity, 06 = threat-intel. Independent
> review established that the MCP boundary is more urgent, so data-integrity moves to 06
> and threat-intel to 07. `HANDOFF.md` records the change.

## Why

Two defects, both verified by execution, and one omission found in review.

**1. The server cannot speak MCP.** `stdio.ex` implements LSP framing — `read_headers/1`
requires `\r\n\r\n`, `write_message/1` emits `Content-Length:` — while the MCP stdio
binding at every revision, including the `2024-11-05` this server advertises, is
newline-delimited JSON. The spec at that git tag: *"Messages are delimited by newlines,
and MUST NOT contain embedded newlines."*

```
$ printf '{"jsonrpc":"2.0","id":1,"method":"initialize",...}\n' | timeout 45 ./bin/hacktui-mcp
   (no response)
$ printf 'Content-Length: 143\r\n\r\n{...}' | timeout 45 ./bin/hacktui-mcp
   Content-Length: 170 ... {"result":{...}}
```

The repo contains its own conformant client — `bin/hacktui-mcp-smoke` writes
`json.dumps(request) + "\n"` — and it **hangs**, killed at 180s. `README.md:459` tells
users to run it. There is no test of `Stdio` anywhere, which is why this shipped.

So `README.md:11` ("AI interoperability through MCP") and, more sharply,
`docs/mcp_stdio_quickstart.md:3` ("**or any other MCP client**") are false.

**2. A caller can forge fields on any tool response.** `normalize_argument_key/1`
allowlists seven keys and retains everything else as **string** keys;
`ProposalService.propose_action/2` sets its safety fields with **atom** keys via
`Map.put_new`, which cannot see them; `to_json_value/1` stringifies and collapses the
collision, caller's value winning:

```
sent:     {"requires_approval": false, "status": "approved"}
returned: {"requires_approval": "false", "status": "approved"}
```

(The boolean arrives as the string `"false"` — `to_json_value/1` stringifies atoms, which
is a second bug: booleans are type-mangled on every tool response.)
`"additionalProperties": false` is declared at `server.ex:276` and never enforced.

**3. Masking is absent from the MCP path** — found in review, not in the original
analysis. `PrivacyMask` appears in 1 file under `apps/hacktui_tui/lib` and **0 files**
under `apps/hacktui_agent/lib`. The TUI masks source and destination IPs; the MCP tool
shipping the same records to a third-party LLM does not. `CLAUDE.md:105` names privacy
masking as a requirement for this exact module.

Combined with (2) this composes into a real attack that needs no network listener: an
adversary who can write bytes into a monitored log or wire — a User-Agent, a hostname, a
DNS name — reaches `raw_message` (`hacktui_sensor.ex:261`), which `get_sensor_logs`
returns verbatim (`query_service.ex:461`) into an analyst's LLM context that is holding a
tool called `propose_action`, whose response fields that adversary can also dictate.

## In scope

1. `stdio.ex`: read newline-delimited JSON; keep `Content-Length` as a tolerated legacy
   path. Always **emit** newline-delimited. Preserve the invariant that only JSON-RPC
   reaches stdout.
2. A real `Stdio` round-trip test, and `bin/hacktui-mcp-smoke` wired into the suite —
   the change that makes this class of defect impossible to ship again.
3. Enforce the declared JSON Schemas in `Dispatch.safe_call/3` before dispatch; reject
   unknown properties; delete the key-widening in `normalize_argument_key/1`. Fixes the
   forgery and honours `limit` for free.
4. Apply masking on the MCP egress path and bound `alert_queue/1` by the advertised
   `limit`.
5. Correct the false docs: `Content-Length: 52` → 58, the two non-existent
   `"2025-11-05"` protocol strings, and the "any other MCP client" claim.
6. `postgrex` → 0.22.4. (The HIGH advisory is **unreachable** here — no
   `Postgrex.Notifications` usage — so this is hygiene, not a fix.)

## Out of scope (section 9)

`disposition` in `normalize_alert/1` and the approval TOCTOU race → slice 06.
ThreatIntel shape unification → slice 07. Booleans being stringified by `to_json_value/1`
is noted in `BACKLOG.md`; fixing it is a behaviour change to every tool response and
belongs with the schema work if it grows.

## Acceptance criteria

- [ ] A conformant newline-delimited `initialize` gets a newline-delimited response.
- [ ] `bin/hacktui-mcp-smoke` completes, and runs in the test suite.
- [ ] Legacy `Content-Length` input still works.
- [ ] A forged `requires_approval`/`status` is rejected, not echoed.
- [ ] `get_latest_alerts` honours `limit` and is bounded.
- [ ] MCP responses are masked.
- [ ] No ratchet regression: test ≤ 7, credo ≤ 77, dialyzer ≤ 43.

## Verification

```bash
printf '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}\n' | timeout 30 ./bin/hacktui-mcp
timeout 60 ./bin/hacktui-mcp-smoke
mix test apps/hacktui_agent/test
```
