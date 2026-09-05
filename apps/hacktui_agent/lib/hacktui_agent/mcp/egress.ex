defmodule HacktuiAgent.MCP.Egress do
  @moduledoc """
  Masks tool responses before they leave the MCP boundary.

  `CLAUDE.md` section 10 names privacy masking as a requirement for this module, and
  `HacktuiHub.PrivacyMask` appeared in **zero** files under `apps/hacktui_agent`. The TUI
  masked source and destination IPs while the MCP tool shipping the same records to a
  third-party model masked nothing.

  This is a funnel, not a per-call-site convention: every read tool's result goes through
  `mask/1`. A value under a field named in `@masked_fields` is walked through maps, lists and
  structs, so identity nested below the key is masked and not only a binary sitting directly
  under it. Charlists, binary map keys, tuples and keyword lists are not walked -- a charlist
  is reassembled unchanged and a key is never inspected. See SCR-195 and SCR-194.

  It is not sufficient on its own. `PrivacyMask` still only recognises RFC1918 and
  loopback IPv4, so hostnames, DNS names, TLS SNI and URIs are masked here only by field
  name, and free text in `raw_message` is not redacted at all. Broadening `PrivacyMask`
  is tracked in `BACKLOG.md`.
  """

  alias HacktuiHub.PrivacyMask

  # Fields known to carry host or network identity.
  @masked_fields ~w(src dst src_host dst_host host host_identity node source_node
                    dns_question tls_sni http_host site indicator)

  @doc "Masks identity-bearing fields in an arbitrary result structure."
  @spec mask(term()) :: term()
  def mask(list) when is_list(list), do: Enum.map(list, &mask/1)

  def mask(%_{} = struct), do: struct |> Map.from_struct() |> mask()

  def mask(map) when is_map(map) do
    Map.new(map, fn {key, value} ->
      if masked?(key), do: {key, mask_value(value)}, else: {key, mask(value)}
    end)
  end

  def mask(other), do: other

  defp masked?(key) when is_atom(key), do: Atom.to_string(key) in @masked_fields
  defp masked?(key) when is_binary(key), do: key in @masked_fields
  defp masked?(_), do: false

  # A masked key declares its whole subtree identity-bearing, so every binary leaf beneath
  # it is masked regardless of the inner key's name. Routing back through mask/1 would mask
  # only inner keys that are themselves in @masked_fields, leaving
  # %{"src" => %{"addr" => "10.0.0.4"}} exposed. Before this recursed, a masked key was the
  # LESS safe place to put host identity than an unmasked one.
  defp mask_value(value) when is_binary(value), do: PrivacyMask.mask(value)
  defp mask_value(value) when is_list(value), do: Enum.map(value, &mask_value/1)
  defp mask_value(%_{} = value), do: value |> Map.from_struct() |> mask_value()

  defp mask_value(value) when is_map(value),
    do: Map.new(value, fn {key, inner} -> {key, mask_value(inner)} end)

  defp mask_value(value), do: value
end
