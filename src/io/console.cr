require "termios"

module IO
  def cooked
    preserving_tc_mode("can't set IO#cooked") do |mode|
      cooked_from_tc_mode!
      yield self
    end
  end

  def cooked!
    if LibC.tcgetattr(fd, out mode) != 0
      raise Errno.new "can't set IO#cooked!"
    end
    cooked_from_tc_mode!
  end

  macro cooked_from_tc_mode!
    mode.c_iflag |= Termios::InputMode::BRKINT |
                    Termios::InputMode::ISTRIP |
                    Termios::InputMode::ICRNL  |
                    Termios::InputMode::IXON
    mode.c_oflag |= Termios::OutputMode::OPOST
    mode.c_lflag |= Termios::LocalMode::ECHO   |
                    Termios::LocalMode::ECHOE  |
                    Termios::LocalMode::ECHOK  |
                    Termios::LocalMode::ECHONL |
                    Termios::LocalMode::ICANON |
                    Termios::LocalMode::ISIG   |
                    Termios::LocalMode::IEXTEN
    LibC.tcsetattr(fd, Termios::LineControl::TCSANOW, pointerof(mode))
  end

  def raw
    preserving_tc_mode("can't set IO#raw") do |mode|
      raw_from_tc_mode!
      yield self
    end
  end

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

  def read_nonblock(size)
    before = LibC.fcntl(fd, LibC::F_GETFL)
    LibC.fcntl(fd, LibC::F_SETFL, before | LibC::O_NONBLOCK)

    begin
      String.new(size) do |buffer|
        read_size = read Slice.new(buffer, size)
        if read_size == 0
          raise EOFError.new "read_nonblock: read nothing"
        elsif Errno.value == LibC::EWOULDBLOCK
          raise Errno.new "exception in read_nonblock"
        else
          {read_size.to_i, 0}
        end
      end
    ensure
      LibC.fcntl(fd, LibC::F_SETFL, before)
    end
  end
end
