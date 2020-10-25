# Crex

Use cron-like syntax to run jobs in Elixir.

- Easy config
- Tiny and readable
- Cluster support
- Telemetry and phx_dashboard

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
```

```elixir
defmodule MyApp.Application do
  use Application

  def start(_type, _args) do
    children = [
      MyApp.CrexSupervisor
     ...
```

## Erlang cluster
Crex runs each job once per cluster. Even though all nodes start all Crex processes,
each job is allocated to one machine. For example, it allocates 3 jobs to 2 nodes like:

```elixir
%{node_1: job_1, node_2: job_2, node_1: job_3}
```

Make sure `Node.list()` returns all nodes in the cluster for this to work.

But if you need to run the function on all nodes, use the `:all` option:

```elixir
  {Crex, ["* * * * * *", {MyApp.Scheduler, :run_in_all_nodes, []}, :all]},
  {Crex, ["* * * * * *", {MyApp.Scheduler, :run_in_single_node, []}]},
```


## Caution
1. On net splits, each partition allocates all the jobs. Thus, the jobs will run once per partition.
If the job cannot run multiple times even in unusual netsplits, you need global state outside Erlang,
like Redis or DB. Something like:

```elixir
defmodule MyApp.Helpers do
  def with_lock(global_key, job_fun) do
    # Has to be atomic to prevent race condition
    if set_unexistent(global_key, true) do
      try do
        job_fun.()
      after
        unset(global_key)
      end
    end
  end
end
```

And then in `application.ex`

```elixir
  {Crex, ["* * * * * *", {MyApp.Helpers, :with_lock, ["foo:bar", fn -> Foo.bar() end]}]},
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

