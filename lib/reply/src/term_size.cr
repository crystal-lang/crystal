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

  module Reply::Term::Size
    def self.size : {Int32, Int32}
      LibC.GetConsoleScreenBufferInfo(LibC.GetStdHandle(LibC::STD_OUTPUT_HANDLE), out csbi)
      col = csbi.srWindow.right - csbi.srWindow.left + 1
      row = csbi.srWindow.bottom - csbi.srWindow.top + 1

      {col.to_i32, row.to_i32}
    end
  end
{% else %}
  lib LibC
    struct Winsize
      row : LibC::Short
      col : LibC::Short
      x_pixel : LibC::Short
      y_pixel : LibC::Short
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

    fun ioctl(fd : LibC::Int, request : LibC::SizeT, winsize : LibC::Winsize*) : LibC::Int
  end

  module Reply::Term::Size
    # Gets the terminals width
    def self.size : {Int32, Int32}
      ret = LibC.ioctl(1, LibC::TIOCGWINSZ, out screen_size)
      raise "Error retrieving terminal size: ioctl TIOCGWINSZ: #{Errno.value}" if ret < 0

      {screen_size.col.to_i32, screen_size.row.to_i32}
    end
  end
{% end %}

module Reply::Term::Size
  def self.width
    size[0]
  end

  def self.height
    size[1]
  end
end
