defmodule ExNcurses.Server do
  use GenServer
  alias ExNcurses.Nif

  @moduledoc """
  This module serializes access to the ncurses NIF to avoid race conditions and
  handles enif_select notifications.
  """

  defmodule State do
    @moduledoc false
    defstruct pid: nil
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @doc """
  Initialize the the ncurses library on the specified terminal.

  If "", the current terminal (the one with the IEx prompt)
  is used. You can also specify another terminal.
  """
  def newterm(term, ttyname) do
    GenServer.call(__MODULE__, {:newterm, term, ttyname})
  end

  @doc """
  Stop using ncurses.
  """
  def endwin() do
    GenServer.call(__MODULE__, :endwin)
  end

  @doc """
  Invoke a ncurses C function
  """
  def invoke(name, args \\ {}) do
    GenServer.call(__MODULE__, {:invoke, name, args})
  end

  @doc """
  Listen for events from ncurses
  """
  def listen() do
    GenServer.call(__MODULE__, :listen)
  end

  @doc """
  Stop listening for events from ncurses
  """
  def stop_listening() do
    GenServer.call(__MODULE__, :stop_listening)
  end

  def init(_args) do
    {:ok, %State{}}
  end

  def handle_call({:newterm, term, ttyname}, _from, state) do
    # Handling the case where termname specifies the terminal with the console:
    #
    # The NIF swaps out stdin in the call to newterm so that the IEx console or
    # any Erlang console code doesn't processes keys that should go to ncurses.
    # In order for this to work reliably, the stdin filehandle cannot be in
    # use.  Specifically, it can't be submitted to a syscall since the swapping
    # procedure causes an error on any in progress syscalls.  To fix this, tell
    # the Erlang scheduler to only allow one OS thread during the swap. This
    # would normally be an unforgivable offense to the Erlang VM, but
    # presumably ncurses isn't being initialized frequently.
    :erlang.system_flag(:multi_scheduling, :block)
    rc = Nif.newterm(term, ttyname)
    :erlang.system_flag(:multi_scheduling, :unblock)

    # Assuming initialization was ok, start polling stdin for key presses
    # and setup the sigwinch handler
    if rc == :ok do
      :ok = Nif.setup_sigwinch(self())
      :ok = Nif.poll()
    end

    {:reply, rc, state}
  end

  def handle_call(:endwin, _from, state) do
    :erlang.system_flag(:multi_scheduling, :block)
    rc = Nif.endwin()
    :erlang.system_flag(:multi_scheduling, :unblock)
    {:reply, rc, state}
  end

  def handle_call({:invoke, name, args}, _from, state) do
    {:reply, Nif.invoke(name, args), state}
  end

  def handle_call(:listen, {pid, _ref}, state) do
    {:reply, :ok, %{state | pid: pid}}
  end

  def handle_call(:stop_listening, _from, state) do
    {:reply, :ok, %{state | pid: nil}}
  end

  def handle_info({:select, _res, _ref, :ready_input}, state) do
    key = Nif.read()

    # Avoid duplicate `:resize` keys.  See `:sigwinch` handler, below.
    if key != :resize do
      maybe_send(state.pid, {:ex_ncurses, :key, key})
    end

    {:noreply, state}
  end

  # Ordinarily, ncurses' own SIGWINCH handler would send a fake `KEY_RESIZE`
  # event via `getch`.  However, because we don't `getch` until we detect real
  # input (via `:select`), we can't respond to terminal resizes in a timely
  # fashion.
  #
  # This signal handler fixes that.  By the time we receive this, the original
  # ncurses SIGWINCH handler will have already been called, and ncurses will
  # have resized itself to the new terminal size.
  def handle_info({:sigwinch, _signum}, state) do
    maybe_send(state.pid, {:ex_ncurses, :key, :resize})
    {:noreply, state}
  end

  defp maybe_send(nil, _message), do: :ok
  defp maybe_send(pid, message), do: send(pid, message)
end
