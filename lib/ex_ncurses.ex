defmodule ExNcurses do
  use Bitwise

  alias ExNcurses.{Getstr, Server}

  @moduledoc """
  ExNcurses lets Elixir programs create text-based user interfaces using ncurses.

  Aside from keyboard input, ExNcurses looks almost like a straight translation of the C-based
  ncurses API. ExNcurses sends key events via messages. See `listen/0` for this.

  Ncurses documentation can be found at:
  * [The ncurses project page](https://www.gnu.org/software/ncurses/)
  * [opengroup.org](http://pubs.opengroup.org/onlinepubs/7908799/xcurses/curses.h.html)
  * [] for ncurses documentation.
  """

  @type pair :: non_neg_integer()
  @type color_name :: :black | :red | :green | :yellow | :blue | :magenta | :cyan | :white
  @type color :: 0..7 | color_name()
  @type window :: reference()
  @type key ::
          0..255
          | :down
          | :up
          | :left
          | :right
          | :home
          | :backspace
          | :f0
          | :f1
          | :f2
          | :f3
          | :f4
          | :f5
          | :f6
          | :f7
          | :f8
          | :f9
          | :f10
          | :f11
          | :f12
          | :f13
          | :f14

  @spec addstr(String.t()) :: :ok
  def addstr(s), do: Server.invoke(:addstr, {s})

  defp attr_build(call, attrs) when is_list(attrs) do
    attrs =
      attrs
      |> Enum.map(fn attr ->
        case attr do
          :standout ->
            1 <<< 16

          :underline ->
            1 <<< 17

          :reverse ->
            1 <<< 18

          :blink ->
            1 <<< 19

          :dim ->
            1 <<< 20

          :bold ->
            1 <<< 21

          :alt_charset ->
            1 <<< 22

          :invis ->
            1 <<< 23

          :protect ->
            1 <<< 24

          :horizontal ->
            1 <<< 25

          :left ->
            1 <<< 26

          :low ->
            1 <<< 27

          :right ->
            1 <<< 28

          :top ->
            1 <<< 29

          :vertical ->
            1 <<< 30

          # num < 256 represents a color pair
          attr when attr < 1 <<< 8 ->
            attr <<< 8

          _ ->
            attr
        end
      end)
      |> Enum.reduce(&(&1 ||| &2))

    Server.invoke(call, {attrs})
  end

  defp attr_build(call, attrs), do: attr_build(call, [attrs])

  @doc """
  Turn off the bit-masked attribute values pass in on the current screen.

  Can take a single value or List of values from the following:

  * A number less than 256 which is assumed to be a color pair
  * Any of `:underline`, `:reverse`, `:blink`, `:dim`, `:bold`, `:alt_charset`, `:invis`,
  `:protect`, `:horizontal`, `:left`, `:low`, `:right`, `:top`, `:vertical`
  """
  @spec attroff(non_neg_integer()) :: :ok
  def attroff(attrs), do: attr_build(:attroff, attrs)

  @doc """
  Turn on the bit-masked attribute values pass in on the current screen.

  Can take a single value or List of values from the following:

  * A number less than 256 which is assumed to be a color pair
  * Any of `:underline`, `:reverse`, `:blink`, `:dim`, `:bold`, `:alt_charset`, `:invis`,
  `:protect`, `:horizontal`, `:left`, `:low`, `:right`, `:top`, `:vertical`
  """
  @spec attron(non_neg_integer()) :: :ok
  def attron(attrs), do: attr_build(:attron, attrs)

  @doc """
  Sets attributes to the specified value

  Can take a single value or List of values from the following:

  * A number less than 256 which is assumed to be a color pair
  * Any of `:underline`, `:reverse`, `:blink`, `:dim`, `:bold`, `:alt_charset`, `:invis`,
  `:protect`, `:horizontal`, `:left`, `:low`, `:right`, `:top`, `:vertical`
  """
  @spec attrset(non_neg_integer()) :: :ok
  def attrset(attrs), do: attr_build(:attrset, attrs)

  @spec beep() :: :ok
  def beep(), do: Server.invoke(:beep)

  @doc """
  Draw a border around the current window.
  """
  @spec border() :: :ok
  def border(), do: Server.invoke(:border, {})

  @spec cbreak() :: :ok
  def cbreak(), do: Server.invoke(:cbreak)

  @doc """
  Clear the screen
  """
  @spec clear() :: :ok
  def clear(), do: Server.invoke(:clear)

  defp color_to_number(x) when is_integer(x), do: x
  defp color_to_number(:black), do: 0
  defp color_to_number(:red), do: 1
  defp color_to_number(:green), do: 2
  defp color_to_number(:yellow), do: 3
  defp color_to_number(:blue), do: 4
  defp color_to_number(:magenta), do: 5
  defp color_to_number(:cyan), do: 6
  defp color_to_number(:white), do: 7

  @doc """
  Return the number of visible columns
  """
  @spec cols() :: non_neg_integer()
  def cols(), do: Server.invoke(:cols)

  @doc """
  Set the cursor mode

  * 0 = Invisible
  * 1 = Terminal-specific normal mode
  * 2 = Terminal-specific high visibility mode
  """
  @spec curs_set(0..2) :: :ok
  def curs_set(visibility), do: Server.invoke(:curs_set, {visibility})

  @doc """
  Delete a window `w`. This cleans up all memory resources associated with it. The application
  must delete subwindows before deleteing the main window.
  """
  @spec delwin(window()) :: :ok
  def delwin(w), do: Server.invoke(:delwin, {w})

  @doc """
  Stop using ncurses and clean the terminal back up.
  """
  @spec endwin() :: :ok
  defdelegate endwin(), to: Server

  @spec flushinp() :: :ok
  def flushinp(), do: Server.invoke(:flushinp)

  @doc """
  Poll for a key press.

  See `listen/0` for a better way of getting keyboard input.
  """
  @spec getch() :: key()
  def getch() do
    listen()

    c =
      receive do
        {:ex_ncurses, :key, key} -> key
      end

    stop_listening()
    c
  end

  @doc """
  Poll for a string.
  """
  def getstr() do
    listen()

    noecho()

    str = getstr_loop(Getstr.init(gety(), getx(), 60))

    stop_listening()
    str
  end

  defp getstr_loop(state) do
    receive do
      {:ex_ncurses, :key, key} ->
        case Getstr.process(state, key) do
          {:done, str} ->
            str

          {:not_done, new_state} ->
            getstr_loop(new_state)
        end
    end
  end

  @doc """
  Return the cursor's row.
  """
  @spec gety() :: non_neg_integer()
  def gety(), do: Server.invoke(:gety)

  @doc """
  Return the cursor's column.
  """
  @spec getx() :: non_neg_integer()
  def getx(), do: Server.invoke(:getx)

  @doc """
  Return whether the display supports color
  """
  @spec has_colors() :: boolean()
  def has_colors(), do: Server.invoke(:has_colors)

  @doc """
  Initialize ncurses on a terminal. This should be called before any of the
  other functions.

  By default, ncurses uses the current terminal. If you're debugging or want to
  have IEx available while in ncurses-mode you can also have it use a different
  window. One way of doing this is to open up another terminal session. At the
  prompt, run `tty`. Then pass the path that it returns to this function.
  Currently input doesn't work in this mode.

  TODO: Return stdscr (a window)
  """
  @spec newterm(String.t(), String.t()) :: :ok
  defdelegate newterm(term, ttyname), to: Server

  @doc """
  Initialize ncurses on a terminal. This should be called before any of the
  other functions. This is a helper function that calls `newterm/2` just like
  how `initscr()` calls `newterm()` in C.
  """
  @spec initscr(String.t()) :: :ok
  def initscr(ttyname \\ "") do
    newterm(System.get_env("TERM"), ttyname)
  end

  @doc """
  Initialize a foreground/background color pair
  """
  @spec init_pair(pair(), color(), color()) :: :ok
  def init_pair(pair, f, b),
    do: Server.invoke(:init_pair, {pair, color_to_number(f), color_to_number(b)})

  @doc """
  Enable the terminal's keypad to capture function keys as single characters.
  """
  @spec keypad() :: :ok
  def keypad(), do: Server.invoke(:keypad)

  @doc """
  Return the number of visible lines
  """
  @spec lines() :: non_neg_integer()
  def lines(), do: Server.invoke(:lines)

  @doc """
  Listen for events.

  Events will be sent as messages of the form:

  `{ex_ncurses, :key, key}`
  """
  defdelegate listen(), to: Server

  @doc """
  Move the cursor for the current window to (y, x) relative to the window's orgin.
  """
  @spec move(non_neg_integer(), non_neg_integer()) :: :ok
  def move(y, x), do: Server.invoke(:move, {y, x})

  @spec mvaddstr(non_neg_integer(), non_neg_integer(), String.t()) :: :ok
  def mvaddstr(y, x, s), do: Server.invoke(:mvaddstr, {y, x, s})

  @doc """
  Move the cursor to the new location.
  """
  @spec mvcur(non_neg_integer(), non_neg_integer(), non_neg_integer(), non_neg_integer()) :: :ok
  def mvcur(oldrow, oldcol, newrow, newcol),
    do: Server.invoke(:mvcur, {oldrow, oldcol, newrow, newcol})

  @spec mvprintw(non_neg_integer(), non_neg_integer(), String.t()) :: :ok
  def mvprintw(y, x, s), do: Server.invoke(:mvprintw, {y, x, s})

  # Common initialization
  def n_begin() do
    initscr()
    raw()
    cbreak()
  end

  def n_end() do
    nocbreak()
    endwin()
  end

  @doc """
  Create a new window with number of nlines, number columns, starting y position, and
  starting x position.
  """
  @spec newwin(non_neg_integer(), non_neg_integer(), non_neg_integer(), non_neg_integer()) ::
          window()
  def newwin(nlines, ncols, begin_y, begin_x),
    do: Server.invoke(:newwin, {nlines, ncols, begin_y, begin_x})

  @spec nocbreak() :: :ok
  def nocbreak(), do: Server.invoke(:nocbreak)

  @spec noecho() :: :ok
  def noecho(), do: Server.invoke(:noecho)

  @doc """
  Print the specified string and advance the cursor.
  Unlike the ncurses printw, this version doesn't support format
  specification. It is really the same as `addstr/1`.
  """
  @spec printw(String.t()) :: :ok
  def printw(s), do: Server.invoke(:printw, {s})

  @spec raw() :: :ok
  def raw(), do: Server.invoke(:raw)

  @doc """
  Refresh the display. This needs to be called after any of the print or
  addstr functions to render their changes.
  """
  @spec refresh() :: :ok
  def refresh(), do: Server.invoke(:refresh)

  @doc """
  Dump the contents of the virtual screen to a file.
  """
  @spec scr_dump(String.t()) :: :ok
  def scr_dump(filename), do: Server.invoke(:scr_dump, {filename})

  @doc """
  Call this after initscr to initialize the ncurses data structures.
  """
  @spec scr_init(String.t()) :: :ok
  def scr_init(filename), do: Server.invoke(:scr_init, {filename})

  @doc """
  Sets the virtual screen to the contents of
       filename, which must have been written using scr_dump. The next call
       to doupdate restores the screen to the way it looked in the dump file.
  """
  @spec scr_restore(String.t()) :: :ok
  def scr_restore(filename), do: Server.invoke(:scr_restore, {filename})

  @doc """
  A combination of scr_restore and scr_init.
  """
  @spec scr_set(String.t()) :: :ok
  def scr_set(filename), do: Server.invoke(:scr_set, {filename})

  @doc """
  Enable scrolling on `stdscr`.
  """
  @spec scrollok() :: :ok
  def scrollok(), do: Server.invoke(:scrollok)

  @doc """
  Enable or disable scrolling on a specific window.
  """
  @spec scrollok(window(), boolean()) :: :ok
  def scrollok(w, b), do: Server.invoke(:scrollok, {w, b})

  @doc """
  Set a scrollable region on the `stdscr`
  """
  @spec setscrreg(non_neg_integer(), non_neg_integer()) :: :ok
  def setscrreg(top, bottom), do: Server.invoke(:setscrreg, {top, bottom})

  @doc """
  Enable the use of colors.
  """
  @spec start_color() :: :ok
  def start_color(), do: Server.invoke(:start_color)

  @doc """
  Stop listening for events
  """
  defdelegate stop_listening(), to: Server

  @doc """
  Add a string to a window `win`. This function will advance the cursor position,
  perform special character processing, and perform wrapping.
  """
  @spec waddstr(window(), String.t()) :: :ok
  def waddstr(win, str), do: Server.invoke(:waddstr, {win, str})

  @doc """
  Draw a wborder around a specific window.
  """
  @spec wborder(window()) :: :ok
  def wborder(w), do: Server.invoke(:wborder, {w})

  @spec wclear(window()) :: :ok
  def wclear(w), do: Server.invoke(:wclear, {w})

  @doc """
  Move the cursor associated with the specified window to (y, x) relative to the window's orgin.
  """
  @spec wmove(window(), non_neg_integer(), non_neg_integer()) :: :ok
  def wmove(win, y, x), do: Server.invoke(:wmove, {win, y, x})

  @doc """
  Refresh a window and update the screen.

  This is equivalent to calling `wrefresh/1` and `doupdate/0`.
  """
  @spec wrefresh(window()) :: :ok
  def wrefresh(w), do: Server.invoke(:wrefresh, {w})

  @doc """
  Refresh a window without updating the screen.

  This is useful if you have overlapping windows and you want to eliminate unnecessary screen refreshes.  You can call `wnoutrefresh/1` on each window (from back to front), then call `doupdate/0` at the end to push the changes to the screen.
  """
  @spec wnoutrefresh(window()) :: :ok
  def wnoutrefresh(w), do: Server.invoke(:wnoutrefresh, {w})

  @doc """
  Update the screen.

  Useful in combination with functions that update the internal buffer without updating the screen, e.g. `wnoutrefresh/1`.
  """
  @spec doupdate() :: :ok
  def doupdate(), do: Server.invoke(:doupdate)

  @doc """
  Resize a window.
  """
  @spec wresize(window(), non_neg_integer(), non_neg_integer()) :: :ok
  def wresize(win, lines, cols), do: Server.invoke(:wresize, {win, lines, cols})

  @doc """
  Move a window's origin (upper left) to a new coordinate.
  """
  @spec mvwin(window(), non_neg_integer(), non_neg_integer()) :: :ok
  def mvwin(win, y, x), do: Server.invoke(:mvwin, {win, y, x})

  @doc """
  Returns true if `endwin/0` has been called, and there have been no subsequent refreshes with `refresh/0` or `wrefresh/1`.
  """
  @spec isendwin() :: boolean()
  def isendwin(), do: Server.invoke(:isendwin)
end
