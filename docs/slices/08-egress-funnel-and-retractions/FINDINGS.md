# Slice 08 — FINDINGS

The fourth batched reviewer (claims-verification lens) returned **FAIL**.

Its most important result is the one that reflects best on the process and worst on the
prose: **every number reproduced exactly.** Test counts, failure counts, credo, dialyzer,
deps.audit, and all five `staged-diff-sha256` values recomputed bit-for-bit across five
commits. The quantitative discipline held.

What failed was qualitative, and it is the same shape as slice 01's F3: **prose that ran
ahead of the diff.**

## F1 — One security hole was still open at HEAD

`MCP.Egress` was described in slice 05 as "a funnel — every read tool's result passes
through it". It was four hand-placed `|> Egress.mask()` calls at individual call sites.
`draft_report` was not one of them, and it embeds the *same* case-timeline records that
`get_case_timeline` masks:

```
get_case_timeline: [%{"src" => "[LOCAL_HOST]", "site" => "[LOCAL_HOST]"}]
draft_report:      [%{"src" => "10.0.0.4",     "site" => "192.168.1.1"}]
```

`draft_report` is advertised in `tools/list`, so any MCP client got the unmasked records
by asking for a report instead of a timeline. Masking now happens once, in
`Dispatch.safe_call/3` — which is what "funnel" means. Verified: both tools now return
identical masked output, and a test asserts they stay identical.

## F2 — "Guarantees no tool can take down the transport" was false

`safe_call/3` rescued exceptions and caught `:exit`, but not `:throw`. A thrown term still
ended the client session — the exact failure the slice claimed to have closed. Now caught:

```
result: {:error, %{reason: "tool threw", tool: :get_latest_alerts}}
caller alive: true
```

## F3 — Three "fixed" claims described changes that were never applied

| Claim | Where | Reality |
|---|---|---|
| "`Content-Length: 52` corrected to 58" | slice 05 PLAN + FINDINGS | Never applied. The commit touched only the file's intro paragraph. Running the documented command produced two `-32700 Parse error`s. Actually fixed in slice 07. |
| "All three collectors now log unmatched `handle_info`" | slice 03 PLAN + commit | Two of three. `ProcessSignals` had no catch-all at all, so it **crashed** rather than "silently dropping". Actually fixed in slice 07. |
| "guards ... unit-tested against stubs" | slice 06 FINDINGS + signoff | Zero executing coverage. `FakeRepo` never ran the Multi. Actually fixed in the slice 06 follow-up. |

Plus two completeness errors: "six `with` blocks" was seven (`approve_action` was the one
missed, and it records who authorised a containment action), and "an explicit fallback
rather than a silent coercion to `:open`" described behaviour identical to what it
replaced.

**All are now retracted in place** in the documents that made them — not deleted. A reader
who finds the original text is precisely the failure mode being guarded against, so the
retraction has to live where the claim lived.

## F4 — Citation drift, and a stale HANDOFF

Slice 04's citations (`network.ex:315`, `hacktui_sensor.ex:104,255`) pointed at the tree as
it was one slice earlier; slice 03 had shifted the file, and `hacktui_sensor.ex` never sets
`:packet_capture` at all. Several other off-by-one line references across slices 02 and 05.
The substance held in every case; the citations did not.

`HANDOFF.md` was **not updated once across five slices**, despite `CLAUDE.md` requiring it
at the end of every slice. Its gate table still claimed dialyzer 61 (actual 43),
deps.audit 13 (actual 12), hex.audit 23 (actual 20), and it still described a slice
ordering that the 05/06/07 renumbering had invalidated — which is why slice-02 documents
say "ThreatIntel is slice 06" and slice-06 documents say "slice 08". Now current, with an
explicit renumbering note and a landed-slices table.

`.claude/gate-baseline.json` had been half-updated: `deps_audit_advisories` lowered 13→12
but `hex_audit_advisories` left at 23 for the same dependency bump. Corrected to 20.

## Gate results

| Gate | Before | After |
|---|---|---|
| test failures | 7 | **7** (held; 168 → 171 tests) |
| credo | 77 | **77** (held) |
| dialyzer | 43 | **43** (held) |

## Still open

- `MCP.Egress` masks by field name over a `PrivacyMask` that only recognises RFC1918 and
  loopback IPv4. `summary`, `info`, `path` and `indicators` still carry the same values
  unmasked. **The funnel is now real; the primitive it funnels into is still too narrow.**
- `safe_call` still returns raw exception text to unauthenticated callers.
- Derived `alert_id` still collides across VM restarts.
- Slice 04's `else` clauses and slice 02's repo-present ingest path still have no
  executing coverage.

All in `BACKLOG.md`.
