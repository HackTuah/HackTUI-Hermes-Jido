defmodule Hacktui.Workers.Enricher do
  use GenServer

  # --- Client API ---
  def start_link(_), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  
  def investigate(domain) do
    GenServer.cast(__MODULE__, {:investigate, domain})
  end

  # --- Server Callbacks ---
  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_cast({:investigate, domain}, state) do
    Hacktui.State.add_log("[INTEL] 🔎 Investigating #{domain}...")

    # 1. Resolve the domain to an IP address natively
    case :inet.gethostbyname(Kernel.to_charlist(domain)) do
      {:ok, {:hostent, _, _, :inet, _, [ip_tuple | _]}} ->
        ip_string = ip_tuple |> Tuple.to_list() |> Enum.join(".")
        
        # 2. Query the GeoIP API
        api_url = "http://ip-api.com/json/#{ip_string}?fields=status,country,isp,query"
        
        case Req.get(api_url) do
          {:ok, %{status: 200, body: %{"status" => "success"} = data}} ->
            country = data["country"]
            isp = data["isp"]
            
            # 3. Send the enriched data to your Dashboard logs!
            Hacktui.State.add_log("[INTEL] 🎯 TARGET ACQUIRED: #{domain} -> #{ip_string} | Location: #{country} | ISP: #{isp}")
            
          _ ->
            Hacktui.State.add_log("[INTEL] ⚠️ #{domain} -> #{ip_string} (GeoIP Lookup Failed)")
        end

      _ ->
        Hacktui.State.add_log("[INTEL] ❌ #{domain} -> DNS Resolution Failed (Domain might be dead)")
    end

    {:noreply, state}
  end
end
