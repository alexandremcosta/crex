# Crex

Use cron-like syntax to run periodic jobs in elixir GenServers.

- Minimal config
- Tiny and readable
- Cluster support
- Telemetry and phx_dashboard integration

## Installation

```elixir
# mix.exs

def deps do
  [
    {:crex, "~> 0.1.0"},
  ]
end
```

## Simple Usage

```elixir
defmodule MyApp.Application do
  use Application

  def start(_type, _args) do
    mfa = {Module, :function, ["arg1", "arg2"]}

    children = [
      # everyday at 1:30
      {Crex, ["0 30 1 * * *", mfa]},

      # every second
      {Crex, ["* * * * * *", mfa]},

      # every 5 seconds
      {Crex, ["*/5 * * * * *", mfa]},

      # every minute
      {Crex, ["0 * * * * *", mfa]},

      # every 5 minutes
      {Crex, ["0 */5 * * * *", mfa]}
    ]

    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

If you don't want to this code in application.ex, wrap it in it's own supervisor:
```elixir
defmodule MyApp.CrexSupervisor
  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      # without args every second
      {Crex, ["* * * * * *", {Mod, :fun, []}]},

      # with args every minute
      {Crex, ["0 * * * * *", {Mod, :fun, ["a"]}]}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end


defmodule MyApp.Application do
  use Application

  def start(_type, _args) do
    children = [
      MyApp.CrexSupervisor
    ]

    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

## Erlang cluster
If you deploy above configuration to a cluster of machines, it will run the job on all machines,
since Crex process is started on every machine.

To solve this problem, make sure the nodes are connected (`Node.list()` return all machines)
and use the `:single` option
```elixir
  {Crex, ["* * * * * *", {MyApp.Scheduler, :run_in_all_nodes, []}]},
  {Crex, ["* * * * * *", {MyApp.Scheduler, :run_in_single_node, []}, :single]},
```

Crex will map each job to each machine. For instance, 3 jobs to 2 machines will be allocated like:
```elixir
%{node_1: job_1, node_2: job_2, node_1: job_3}
```

## Caution
1. On net splits, each partition allocates all the jobs. Thus the jobs will run once per partition.
If the job is dangerous to run multiple times even in unusual netsplits, you need global state
outside Erlang, like Redis or DB. Something like:

```elixir
def with_lock(global_key, fun) do
  # Has to be atomic to prevent race condition
  if is_nil_set(global_key, true) do
    try do
      fun.()
    after
      set(global_key, nil)
    end
  end
end
```

2. Cron expressions have second precision and are evaluated over UTC:

```
# ┌───────────── second (0 - 59)
# │ ┌───────────── minute (0 - 59)
# │ │ ┌───────────── hour (0 - 23)
# │ │ │ ┌───────────── day of the week (0 - 6) (Sunday to Saturday)
# │ │ │ │ ┌───────────── month (1 - 12)
# │ │ │ │ │ ┌───────────── year
# │ │ │ │ │ │
# │ │ │ │ │ │
# │ │ │ │ │ │
# * * * * * *
```

3. If a job execution is slow and overlaps the interval until the next run, it won't run.
It will only run again on the next run after it finishes.

## Telemetry and phx_dashboard (TODO)

Inpired by: https://hexdocs.pm/elixir/GenServer.html#module-receiving-regular-messages

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/crex](https://hexdocs.pm/crex).

