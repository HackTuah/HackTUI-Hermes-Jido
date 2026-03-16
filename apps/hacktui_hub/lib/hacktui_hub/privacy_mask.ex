defmodule HacktuiHub.PrivacyMask do
  @moduledoc false

  @mask_enabled Application.compile_env(:hacktui_hub, :privacy_mask, true)
  @local_label "[LOCAL_HOST]"

  def mask(value) when not @mask_enabled, do: value
  def mask(nil), do: nil

  def mask(ip) when is_binary(ip) do
    cond do
      private_ip?(ip) -> @local_label
      loopback_ip?(ip) -> @local_label
      true -> ip
    end
  end

  def mask(other), do: other

  defp private_ip?(ip) do
    String.starts_with?(ip, "10.") or
      String.starts_with?(ip, "192.168.") or
      private_172?(ip)
  end

  defp private_172?(ip) do
    case String.split(ip, ".") do
      ["172", second, _third, _fourth] ->
        case Integer.parse(second) do
          {n, ""} -> n >= 16 and n <= 31
          _ -> false
        end

      _ ->
        false
    end
  end

  defp loopback_ip?(ip) do
    String.starts_with?(ip, "127.") or ip == "::1"
  end
end
