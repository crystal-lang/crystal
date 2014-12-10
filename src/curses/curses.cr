require "./*"

module Curses
  extend self

  def init_screen
    @@stdscr ||= begin
      stdscr = LibCurses.initscr
      unless stdscr
        raise "Couldn't initialize ncurses"
      end
      Window.new stdscr
    end
  end

  def stdscr
    init_screen
  end

  def refresh
    LibCurses.refresh
  end

  def getch
    LibCurses.getch
  end

  def crmode
    LibCurses.cbreak
  end

  def lines
    LibCurses.lines
  end

  def cols
    LibCurses.cols
  end

  def setpos(x, y)
    LibCurses.move(x, y)
  end

  def addstr(str)
    LibCurses.addstr str
  end

  def close_screen
    LibCurses.endwin
  end
end
