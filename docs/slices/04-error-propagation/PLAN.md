# Slice 04 — error-propagation

**Branch:** `slice/04-error-propagation`
**Status:** implemented; review batched to the end of the slice run per maintainer direction
**Depends on:** slice 03 (`f2dceca`)

## Why

Failures were being converted into plausible-looking success. For a SOC console that is
the highest-consequence class of defect: an operator staring at an empty alert queue could
not tell "no alerts" from "the database is unreachable" from "the query is being made to
fail".

## In scope / done

1. **The MCP transport crash.** `|>` binds tighter than `||`, so in
   `query_service.ex` the `to_string |> String.downcase` pipeline applied only to the
   `""` fallback and a real value was returned raw. Collectors emit `collector` as an
   **atom**, so `String.contains?(:packet_capture, "jido")` raised `FunctionClauseError` —
   with no rescue anywhere in `Dispatch → Server → Stdio`, killing the client session.
2. **No tool may kill the transport.** Added `Dispatch.safe_call/3`, now the default
   dispatch function in `MCP.Server`. **RETRACTED (slice 08):** as shipped it rescued
   exceptions and caught `:exit` but **not `:throw`**, so a thrown term still ended the
   session. "Guarantees" was too strong. `:throw` is caught as of slice 08.
3. **Query failures are reported, not swallowed.** `safe_all_query/2` returned `[]` on any
   error. It now logs, records the failure, and the dashboard snapshot carries a
   `:degraded` field.
4. **The TUI shows it.** A red `DEGRADED: read failed (...)` banner in the header.
5. **The false docstring is gone.** `QueryService`'s moduledoc claimed "no hidden rescue
   path that turns real alerts into an empty queue" 484 lines above exactly that path.
6. **Six `with` blocks no longer leak.** **RETRACTED (slice 08):** there are seven.
   `approve_action/3` -- the one that records who authorised a containment action -- was
   missed, and slice 06's guards then made its leak reachable. Fixed in the slice 06
   follow-up. `HacktuiStore` returns `Ecto.Multi`'s
   `{:error, step, reason, changes}`; every public `Runtime` function is `@spec`'d
   `{:ok, map()} | {:error, term()}` and none had an `else`. `Forwarder`'s
   `normalize_rpc_result/1` then converted that leak into **success**.

## Out of scope (section 9)

Data integrity — transactions, unique constraints, lifecycle round-tripping (slice 05).
ThreatIntel shape unification (slice 06). MCP authentication and authorization (slice 07).

## Verification

```bash
mix test apps/hacktui_hub/test/error_propagation_test.exs
mix test apps/hacktui_agent/test/mcp_dispatch_safety_test.exs
```
