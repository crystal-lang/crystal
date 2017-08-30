require "termios"

class IO::FileDescriptor < IO
  # Turn off character echoing for the duration of the given block.
  # This will prevent displaying back to the user what they enter on the terminal.
  # Only call this when this IO is a TTY, such as a not redirected stdin.
  #
  # ```
  # print "Enter password: "
  # password = STDIN.noecho &.gets.try &.chomp
  # puts
  # ```
  def noecho
    preserving_tc_mode("can't set IO#noecho") do |mode|
      noecho_from_tc_mode!
      yield self
    end
  end

  # Turn off character echoing for this IO.
  # This will prevent displaying back to the user what they enter on the terminal.
  # Only call this when this IO is a TTY, such as a not redirected stdin.
  def noecho!
    if LibC.tcgetattr(fd, out mode) != 0
      raise Errno.new "can't set IO#noecho!"
    end
    noecho_from_tc_mode!
  end

  macro noecho_from_tc_mode!
    mode.c_lflag &= ~(Termios::LocalMode.flags(ECHO, ECHOE, ECHOK, ECHONL).value)
    LibC.tcsetattr(fd, Termios::LineControl::TCSANOW, pointerof(mode))
  end

  # Enable character processing for the duration of the given block.
  # The so called cooked mode is the standard behavior of a terminal,
  # doing line wise editing by the terminal and only sending the input to
  # the program on a newline.
  # Only call this when this IO is a TTY, such as a not redirected stdin.
  def cooked
    preserving_tc_mode("can't set IO#cooked") do |mode|
      cooked_from_tc_mode!
      yield self
    end
  end

  # Enable character processing for this IO.
  # The so called cooked mode is the standard behavior of a terminal,
  # doing line wise editing by the terminal and only sending the input to
  # the program on a newline.
  # Only call this when this IO is a TTY, such as a not redirected stdin.
  def cooked!
    if LibC.tcgetattr(fd, out mode) != 0
      raise Errno.new "can't set IO#cooked!"
    end
    cooked_from_tc_mode!
  end

  macro cooked_from_tc_mode!
    mode.c_iflag |= (Termios::InputMode::BRKINT |
                    Termios::InputMode::ISTRIP |
                    Termios::InputMode::ICRNL  |
                    Termios::InputMode::IXON).value
    mode.c_oflag |= Termios::OutputMode::OPOST.value
    mode.c_lflag |= (Termios::LocalMode::ECHO   |
                    Termios::LocalMode::ECHOE  |
                    Termios::LocalMode::ECHOK  |
                    Termios::LocalMode::ECHONL |
                    Termios::LocalMode::ICANON |
                    Termios::LocalMode::ISIG   |
                    Termios::LocalMode::IEXTEN).value
    LibC.tcsetattr(fd, Termios::LineControl::TCSANOW, pointerof(mode))
  end

  # Enable raw mode for the duration of the given block.
  # In raw mode every keypress is directly sent to the program, no interpretation
  # is done by the terminal.
  # Only call this when this IO is a TTY, such as a not redirected stdin.
  def raw
    preserving_tc_mode("can't set IO#raw") do |mode|
      raw_from_tc_mode!
      yield self
    end
  end

  # Enable raw mode for this IO.
  # In raw mode every keypress is directly sent to the program, no interpretation
  # is done by the terminal.
  # Only call this when this IO is a TTY, such as a not redirected stdin.
  def raw!
    if LibC.tcgetattr(fd, out mode) != 0
      raise Errno.new "can't set IO#raw!"
    end

    raw_from_tc_mode!
  end

  macro raw_from_tc_mode!
    LibC.cfmakeraw(pointerof(mode))
    LibC.tcsetattr(fd, Termios::LineControl::TCSANOW, pointerof(mode))
  end

  private def preserving_tc_mode(msg)
    if LibC.tcgetattr(fd, out mode) != 0
      raise Errno.new msg
    end
    before = mode
    begin
      yield mode
    ensure
      LibC.tcsetattr(fd, Termios::LineControl::TCSANOW, pointerof(before))
    end
  end
end
