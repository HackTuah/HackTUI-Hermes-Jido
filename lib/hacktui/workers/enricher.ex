defmodule Hacktui.Workers.Enricher do
  use GenServer

  def start_link(_), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  
  def investigate(domain) do
    GenServer.cast(__MODULE__, {:investigate, domain})
  end

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_cast({:investigate, domain}, state) do
    Hacktui.State.add_log("[INTEL] 🔎 Investigating #{domain}...")

    Task.start(fn ->
      case :inet.gethostbyname(Kernel.to_charlist(domain)) do
        {:ok, {:hostent, _, _, :inet, _, [ip_tuple | _]}} ->
          ip_string = ip_tuple |> Tuple.to_list() |> Enum.join(".")
          api_url = "http://ip-api.com/json/#{ip_string}?fields=status,country,isp,query"
          
          case Req.get(api_url) do
            {:ok, %{status: 200, body: %{"status" => "success"} = data}} ->
              intel = %{ip: ip_string, country: data["country"], isp: data["isp"]}
              Hacktui.State.add_log("[INTEL] 🎯 TARGET ACQUIRED: #{domain} -> #{ip_string}")
              Hacktui.State.add_intel(domain, intel)
              
            _ ->
              Hacktui.State.add_log("[INTEL] ⚠️ #{domain} (GeoIP Lookup Failed)")
          end

        _ ->
          Hacktui.State.add_log("[INTEL] ❌ #{domain} -> DNS Resolution Failed")
          # PRO FIX: Send "DEAD" entry to the map so it is recorded
          dead_intel = %{ip: "0.0.0.0", country: "N/A", isp: "UNRESOLVED/NXDOMAIN"}
          Hacktui.State.add_intel(domain, dead_intel)
      end
    end)

    {:noreply, state}
  end
end
