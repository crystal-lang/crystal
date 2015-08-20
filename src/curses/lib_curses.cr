@[Link("ncurses")]
lib LibCurses
  type Window = Void*

  alias Int = LibC::Int
  alias Char = LibC::Char
  alias Chtype = LibC::UInt

  $lines = LINES : Int
  $cols = COLS : Int

  fun initscr : Window
  fun printw(...)
  fun refresh
  fun getch : Int
  fun cbreak : Int
  fun move(x : Int, y : Int) : Int
  fun wmove(w : Window, x : Int, y : Int) : Int
  fun addstr(s : Char*) : Int
  fun waddstr(w : Window, s : Char*) : Int
  fun newwin(height : Int, width : Int, top : Int, left : Int) : Window
  fun box(w : Window, v : Chtype, h : Chtype) : Int
  fun endwin

  fun delwin(window : Window)
  fun wrefresh(window : Window)
  fun wgetch(window : Window) : Int
end
