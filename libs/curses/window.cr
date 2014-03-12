struct Curses::Window
  def self.new(height, width, top, left)
    new LibCurses.newwin(height, width, top, left)
  end

  def initialize(@window : LibCurses::Window)
  end

  def box(vert : Char, hor : Char)
    LibCurses.box @window, vert.ord, hor.ord
  end

  def setpos(x, y)
    LibCurses.wmove @window, x, y
  end

  def addstr(str)
    LibCurses.waddstr @window, str
  end

  def getch
    LibCurses.wgetch @window
  end

  def refresh
    LibCurses.wrefresh @window
  end

  def close
    LibCurses.delwin @window
  end
end
