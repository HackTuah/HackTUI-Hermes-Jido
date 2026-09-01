# Slice 05 — FINDINGS

## F1 — The server could not speak MCP. Fixed.

`stdio.ex` implemented LSP framing. The MCP stdio binding at `2024-11-05` — the revision
this server advertises — and every revision since:

> "Messages are delimited by newlines, and MUST NOT contain embedded newlines."

Before:
```
$ printf '{"jsonrpc":"2.0","id":1,"method":"initialize",...}\n' | timeout 45 ./bin/hacktui-mcp
  (no response)
```
After:
```
$ printf '{"jsonrpc":"2.0","id":1,"method":"initialize",...}\n' | timeout 60 ./bin/hacktui-mcp
{"id":1,"jsonrpc":"2.0","result":{...,"serverInfo":{"name":"hacktui-hermes",...}}}
```
Legacy `Content-Length` input still accepted; output is always newline-delimited.

**The decisive evidence was already in the repo.** `bin/hacktui-mcp-smoke` writes
newline-delimited JSON — correct MCP framing — and `README.md:459` tells users to run it.
It hung until killed. Now:
```
$ timeout 120 ./bin/hacktui-mcp-smoke
MCP initialize ok
protocolVersion=2024-11-05
server=hacktui-hermes version=0.1.0
exit=0
```

There was **no test of `Stdio` at all**, which is why this shipped. There are now four,
including one that runs the smoke client, so the defect cannot recur silently.

**RETRACTED (slice 08):** this document originally said `docs/mcp_stdio_quickstart.md`
had been corrected from `Content-Length: 52` for a 58-byte body. **It had not.** The
commit touched only that file's intro paragraph; line 25 was untouched, and running the
command the doc prints produced two `-32700 Parse error`s. Actually corrected in slice 07.
Also corrected: `README.md` advertised
`"protocolVersion":"2025-11-05"` twice, a revision that does not exist.

## F2 — A caller could dictate fields on any tool response. Fixed.

`normalize_argument_key/1` allowlisted seven keys and **retained everything else as
string keys**; `ProposalService.propose_action/2` set its safety fields with **atom** keys
via `Map.put_new`, blind to them; `to_json_value/1` stringified and collapsed the
collision with the caller's value winning.

End to end, before:
```
sent:     {"requires_approval": false, "status": "approved"}
returned: {"requires_approval": "false", "status": "approved"}
```
After:
```
{"id":7,...,"isError":true,"content":[{"text":"...invalid arguments:
  unknown properties: requires_approval, status..."}]}
{"id":8,...,"isError":false,"content":[{"text":"{... \"requires_approval\": \"true\",
  \"status\": \"proposal\" ...}"}]}
```

The declared schemas are now enforced at the wire boundary, before normalisation, so
`required` and `additionalProperties` mean what `tools/list` says. The key-widening is
deleted.

This also fixes the advertised-but-discarded `limit` for free: `maximum: 100` is enforced
and `get_latest_alerts` is bounded rather than returning the whole table.

**Note on the earlier report:** an initial summary of this bug stated the forged value
returned as the boolean `false`. It returns the **string** `"false"` — `to_json_value/1`
stringifies atoms, which is a separate bug (booleans are type-mangled on every tool
response). Logged in `BACKLOG.md`; fixing it changes every response shape.

## F3 — Masking was absent from the MCP path. Fixed.

`PrivacyMask` appeared in 1 file under `apps/hacktui_tui/lib` and **0 files** under
`apps/hacktui_agent/lib`. The TUI masked source and destination IPs; the MCP tool
shipping the same records to a third-party model masked nothing. `CLAUDE.md:105` names
privacy masking as a requirement for this module.

**RETRACTED (slice 08):** "funnel" was inaccurate. It was four hand-placed `|> Egress.mask()`
calls at individual call sites, and `draft_report` -- which embeds the same case timeline
`get_case_timeline` masks -- was not one of them, so it egressed unmasked. Masking is now
applied once in `Dispatch.safe_call/3`, which is a funnel. Original text:

Added `MCP.Egress` as a funnel — every read tool's result passes through it:
```
before: [%{payload: %{"src" => "10.0.0.4", "site" => "192.168.1.1"}}]
after:  [%{payload: %{"src" => "[LOCAL_HOST]", "site" => "[LOCAL_HOST]"}}]
```

**This is not sufficient.** `PrivacyMask` still recognises only RFC1918 and loopback
IPv4, so public IPs, hostnames, DNS names, TLS SNI and URIs pass through, and free text
in `raw_message` is not redacted at all. Broadening it is in `BACKLOG.md`.

## F4 — postgrex bumped

0.22.0 → 0.22.4. `deps.audit` advisories 13 → 12. The HIGH channel-name SQL-injection
advisory is **unreachable in this codebase** — `grep -rn "Postgrex.Notifications"` returns
nothing — so this is hygiene, not a fix, and was mis-ranked as urgent in an earlier
summary.

## Gate results

| Gate | Before | After |
|---|---|---|
| test failures | 7 | **7** (held; 140 → 152 tests) |
| credo | 77 | **77** (held) |
| dialyzer | 43 | **43** (held) |
| deps.audit | 13 | **12** |

The dialyzer ratchet caught one regression during this slice: removing the key-widening
made `normalize_arguments(_)` unreachable, since `Schema.validate/2` now rejects non-maps
first. Dead clause removed.
