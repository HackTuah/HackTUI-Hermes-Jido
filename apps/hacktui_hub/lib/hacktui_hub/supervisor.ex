defmodule HacktuiHub.Supervisor do
  @moduledoc false
  use Supervisor

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    children = [
      {Registry, keys: :unique, name: HacktuiHub.Registry},
      # Previously started lazily by IngestService via GenServer.start/3 -- unlinked,
      # unsupervised, and silently re-created empty after any crash.
      {HacktuiHub.IngestBuffer, limit: 100},
      # Previously in no supervision tree at all, so :threat_intel_keywords never
      # existed and Indexer.lookup/1 raised on every observation -- swallowed by a
      # blanket rescue in IngestService.
      HacktuiHub.ThreatIntel.Indexer,
      {Task.Supervisor, name: HacktuiHub.TaskSupervisor},
      {Task.Supervisor, name: HacktuiHub.IngestSupervisor},
      {Task.Supervisor, name: HacktuiHub.DetectionSupervisor},
      {Task.Supervisor, name: HacktuiHub.CaseworkSupervisor},
      {Task.Supervisor, name: HacktuiHub.ResponseSupervisor},
      {Task.Supervisor, name: HacktuiHub.PolicySupervisor},
      {Task.Supervisor, name: HacktuiHub.AuditSupervisor}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
