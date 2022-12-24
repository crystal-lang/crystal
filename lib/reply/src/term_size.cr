# Implementation inspired from https://github.com/crystal-term/screen/blob/master/src/term-screen.cr.
module Reply::Term::Size
  extend self

  DEFAULT_SIZE = {80, 27}

  def width
    self.size[0]
  end

  def height
    self.size[1]
  end

  private def check_size(size)
    if size && (cols = size[0]) && (rows = size[1]) && cols != 0 && rows != 0
      {cols, rows}
    end
  end

  {% if flag?(:win32) %}
    def size : {Int32, Int32}
      check_size(size_from_screen_buffer) ||
        check_size(size_from_ansicon) ||
        DEFAULT_SIZE
    end

    # Detect terminal size Windows GetConsoleScreenBufferInfo
    private def size_from_screen_buffer
      LibC.GetConsoleScreenBufferInfo(LibC.GetStdHandle(LibC::STD_OUTPUT_HANDLE), out csbi)
      cols = csbi.srWindow.right - csbi.srWindow.left + 1
      rows = csbi.srWindow.bottom - csbi.srWindow.top + 1

      {cols.to_i32, rows.to_i32}
    end

    # Detect terminal size from Windows ANSICON
    private def size_from_ansicon
      return unless ENV["ANSICON"]?.to_s =~ /\((.*)x(.*)\)/

      rows, cols = [$2, $1].map(&.to_i)
      {cols, rows}
    end
  {% else %}
    def size : {Int32, Int32}
      size_from_ioctl(0) ||   # STDIN
        size_from_ioctl(1) || # STDOUT
        size_from_ioctl(2) || # STDERR
        check_size(size_from_tput) ||
        check_size(size_from_stty) ||
        check_size(size_from_env) ||
        DEFAULT_SIZE
    end

    # Read terminal size from Unix ioctl
    private def size_from_ioctl(fd)
      winsize = uninitialized LibC::Winsize
      ret = LibC.ioctl(fd, LibC::TIOCGWINSZ, pointerof(winsize))
      return if ret < 0

      {winsize.ws_col.to_i32, winsize.ws_row.to_i32}
    end

    # Detect terminal size from tput utility
    private def size_from_tput
      return unless STDOUT.tty?

      lines = `tput lines`.to_i?
      cols = `tput cols`.to_i?

      {cols, lines}
    rescue
      nil
    end

    # Detect terminal size from stty utility
    private def size_from_stty
      return unless STDOUT.tty?

      parts = `stty size`.split(/\s+/)
      return unless parts.size > 1
      lines, cols = parts.map(&.to_i?)

      {cols, lines}
    rescue
      nil
    end

    # Detect terminal size from environment
    private def size_from_env
      return unless ENV["COLUMNS"]?.to_s =~ /^\d+$/

      rows = ENV["LINES"]? || ENV["ROWS"]?
      cols = ENV["COLUMNS"]?

      {cols.try &.to_i?, rows.try &.to_i?}
    end
  {% end %}
end

{% if flag?(:win32) %}
  lib LibC
    struct COORD
      x : Int16
      y : Int16
    end

    struct SMALL_RECT
      left : Int16
      top : Int16
      right : Int16
      bottom : Int16
    end

    struct CONSOLE_SCREEN_BUFFER_INFO
      dwSize : COORD
      dwCursorPosition : COORD
      wAttributes : UInt16
      srWindow : SMALL_RECT
      dwMaximumWindowSize : COORD
    end

    STD_OUTPUT_HANDLE = -11

    fun GetConsoleScreenBufferInfo(hConsoleOutput : Void*, lpConsoleScreenBufferInfo : CONSOLE_SCREEN_BUFFER_INFO*) : Void
    fun GetStdHandle(nStdHandle : UInt32) : Void*
  end
{% else %}
  lib LibC
    struct Winsize
      ws_row : UShort
      ws_col : UShort
      ws_xpixel : UShort
      ws_ypixel : UShort
    end

    # TIOCGWINSZ is a magic number passed to ioctl that requests the current
    # terminal window size. It is platform dependent (see
    # https://stackoverflow.com/a/4286840).
    {% begin %}
      {% if flag?(:darwin) || flag?(:bsd) %}
        TIOCGWINSZ = 0x40087468
      {% elsif flag?(:unix) %}
        TIOCGWINSZ = 0x5413
      {% end %}
    {% end %}

    fun ioctl(fd : Int, request : ULong, ...) : Int
  end
{% end %}
