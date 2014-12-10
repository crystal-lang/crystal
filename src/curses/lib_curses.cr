@[Link("ncurses")]
lib LibCurses
  type Window = Void*

  $lines = LINES : Int32
  $cols = COLS : Int32

  fun initscr : Window
  fun printw(...)
  fun refresh
  fun getch : Int32
  fun cbreak : Int32
  fun move(x : Int32, y : Int32) : Int32
  fun wmove(w : Window, x : Int32, y : Int32) : Int32
  fun addstr(s : UInt8*) : Int32
  fun waddstr(w : Window, s : UInt8*) : Int32
  fun newwin(height : Int32, width : Int32, top : Int32, left : Int32) : Window
  fun box(w : Window, v : Int32, h : Int32) : Int32
  fun endwin

  fun delwin(window : Window)
  fun wrefresh(window : Window)
  fun wgetch(window : Window) : Int32
end
