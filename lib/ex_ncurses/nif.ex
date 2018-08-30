defmodule ExNcurses.Nif do
  @moduledoc false

  @compile {:autoload, false}
  @on_load {:load_nif, 0}
  def load_nif() do
    Application.app_dir(:ex_ncurses, "priv/ex_ncurses")
    |> to_charlist
    |> :erlang.load_nif(0)
    |> check_load_result()
  end

  defp check_load_result(:ok), do: :ok

  defp check_load_result({:error, {reason, msg}}) do
    # I'd like to use Logger.error here, but we can't rely
    # on Logger being available yet.
    IO.puts("\nERROR: Failed to load #{__MODULE__} (#{reason}): #{msg}\n")
    :abort
  end

  @doc """
  Initialize ncurses on the specified terminal.
  """
  def newterm(_term, _ttyname), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Poll for events from ncurses. When an event is ready,
  {:select, _res, _ref, :ready_input} will be sent back and
  then `read/0` should be called to get the event.
  """
  def poll(), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Read an event.
  """
  def read(), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Setup the SIGWINCH signal handler.

  Upon receiving SIGWINCH, the original ncurses handler will be called, and
  then a `{:sigwinch, n}` message (where `n` is the signal number) will be
  delivered to `pid`.
  """
  def setup_sigwinch(pid), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Stop using ncurses.
  """
  def endwin(), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Invoke an ncurses function
  """
  def invoke(_function, _args), do: :erlang.nif_error(:nif_not_loaded)
end
