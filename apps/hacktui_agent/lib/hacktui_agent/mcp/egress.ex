defmodule HacktuiAgent.MCP.Egress do
  @moduledoc """
  Masks tool responses before they leave the MCP boundary.

  `CLAUDE.md` section 10 names privacy masking as a requirement for this module, and
  `HacktuiHub.PrivacyMask` appeared in **zero** files under `apps/hacktui_agent`. The TUI
  masked source and destination IPs while the MCP tool shipping the same records to a
  third-party model masked nothing.

  This is a funnel, not a per-call-site convention: every read tool's result goes through
  `mask/1`. It walks maps and lists and masks the fields that carry host identity.

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

  defp mask_value(value) when is_binary(value), do: PrivacyMask.mask(value)
  defp mask_value(value), do: value
end
