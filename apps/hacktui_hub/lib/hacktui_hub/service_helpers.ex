defmodule HacktuiHub.ServiceHelpers do
  @moduledoc false

  @spec fetch_option!(keyword(), atom()) :: any()
  def fetch_option!(opts, key) do
    Keyword.fetch!(opts, key)
  end
end
