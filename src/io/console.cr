lib LibTermios
  alias Cc = Char
  alias Tcflag = UInt64
  alias Int = LibC::Int

  struct Struct
    iflag : Tcflag
    oflag : Tcflag
    cflag : Tcflag
    lflag : Tcflag
    cc : Cc*
  end

  enum OptionalActions
    TCSANOW
    TCSADRAIN
    TCSAFLUSH
  end

  # The commented flags are not used yet and for many
  # of them crossplatform availability is uncertain

  @[Flags]
  enum IFlag
    #    IGNBRK  = 0o000001
    BRKINT = 0o000002
    #    IGNPAR  = 0o000004
    #    PARMRK  = 0o000010
    #    INPCK   = 0o000020
    ISTRIP = 0o000040
    #    INLCR   = 0o000100
    #    IGNCR   = 0o000200
    ICRNL = 0o000400
    #    IUCLC   = 0o001000
    IXON = 0o002000
    #    IXANY   = 0o004000
    #    IXOFF   = 0o010000
    #    IMAXBEL = 0o020000
    #    IUTF8   = 0o040000
  end

  @[Flags]
  enum OFlag
    OPOST = 0o000001
    #    OLCUC  = 0o000002
    #    ONLCR  = 0o000004
    #    OCRNL  = 0o000010
    #    ONOCR  = 0o000020
    #    ONLRET = 0o000040
    #    OFILL  = 0o000100
    #    OFDEL  = 0o000200
    # #if defined __USE_MISC || defined __USE_XOPEN
    #    NLDLY  = 0o000400
    #      NL0  = 0o000000
    #      NL1  = 0o000400
    #    CRDLY  = 0o003000
    #      CR0  = 0o000000
    #      CR1  = 0o001000
    #      CR2  = 0o002000
    #      CR3  = 0o003000
    #    TABDLY = 0o014000
    #      TAB0 = 0o000000
    #      TAB1 = 0o004000
    #      TAB2 = 0o010000
    #      TAB3 = 0o014000
    #    BSDLY  = 0o020000
    #      BS0  = 0o000000
    #      BS1  = 0o020000
    #    FFDLY  = 0o100000
    #      FF0  = 0o000000
    #      FF1  = 0o100000
    # #endif
    #    VTDLY  = 0o040000
    #      VT0  = 0o000000
    #      VT1  = 0o040000
    # #ifdef __USE_MISC
    #    XTABS  = 0o014000
    # #endif
  end

  #  enum CFlag
  # #ifdef __USE_MISC
  #    CBAUD  = 0o010017
  # #endif
  #    B0     = 0o000000     # hang up
  #    B50    = 0o000001
  #    B75    = 0o000002
  #    B110   = 0o000003
  #    B134   = 0o000004
  #    B150   = 0o000005
  #    B200   = 0o000006
  #    B300   = 0o000007
  #    B600   = 0o000010
  #    B1200  = 0o000011
  #    B1800  = 0o000012
  #    B2400  = 0o000013
  #    B4800  = 0o000014
  #    B9600  = 0o000015
  #    B19200 = 0o000016
  #    B38400 = 0o000017
  # #ifdef __USE_MISC
  # # define EXTA B19200
  # # define EXTB B38400
  # #endif
  #    CSIZE    = 0o000060
  #    CS5      = 0o000000
  #    CS6      = 0o000020
  #    CS7      = 0o000040
  #    CS8      = 0o000060
  #    CSTOPB   = 0o000100
  #    CREAD    = 0o000200
  #    PARENB   = 0o000400
  #    PARODD   = 0o001000
  #    HUPCL    = 0o002000
  #    CLOCAL   = 0o004000
  # #ifdef __USE_MISC
  #    CBAUDEX  = 0o010000
  # #endif
  #    B57600   = 0o010001
  #    B115200  = 0o010002
  #    B230400  = 0o010003
  #    B460800  = 0o010004
  #    B500000  = 0o010005
  #    B576000  = 0o010006
  #    B921600  = 0o010007
  #    B1000000 = 0o010010
  #    B1152000 = 0o010011
  #    B1500000 = 0o010012
  #    B2000000 = 0o010013
  #    B2500000 = 0o010014
  #    B3000000 = 0o010015
  #    B3500000 = 0o010016
  #    B4000000 = 0o010017
  # #define __MAX_BAUD B4000000
  # #ifdef __USE_MISC
  #    CIBAUD   = 0o02003600000     # input baud rate (not used)
  #    CMSPAR   = 0o10000000000     # mark or space (stick) parity
  #    CRTSCTS  = 0o20000000000     # flow control
  # #endif
  #  end

  @[Flags]
  enum LFlag
    ISIG   = 0o000001
    ICANON = 0o000002
    # #if defined __USE_MISC || defined __USE_XOPEN
    #    XCASE   = 0o000004
    # #endif
    ECHO   = 0o000010
    ECHOE  = 0o000020
    ECHOK  = 0o000040
    ECHONL = 0o000100
    #    NOFLSH  = 0o000200
    #    TOSTOP  = 0o000400
    # #ifdef __USE_MISC
    #    ECHOCTL = 0o001000
    #    ECHOPRT = 0o002000
    #    ECHOKE  = 0o004000
    #    FLUSHO  = 0o010000
    #    PENDIN  = 0o040000
    # #endif
    IEXTEN = 0o100000
    # ifdef __USE_BSD
    EXTPROC = 0o200000
    # endif

  end

  fun cfmakeraw(termios_p : LibTermios::Struct*)
  fun tcgetattr(fd : Int, termios_p : LibTermios::Struct*) : Int
  fun tcsetattr(fd : Int, optional_actions : OptionalActions, termios_p : LibTermios::Struct*) : Int
end

module IO
  def cooked
    preserving_tc_mode("can't set IO#cooked") do |mode|
      cooked_from_tc_mode!
      yield self
    end
  end

  def cooked!
    if LibTermios.tcgetattr(fd, out mode) != 0
      raise Errno.new "can't set IO#cooked!"
    end
    cooked_from_tc_mode!
  end

  macro cooked_from_tc_mode!
    mode.iflag |= LibTermios::IFlag::BRKINT |
                  LibTermios::IFlag::ISTRIP |
                  LibTermios::IFlag::ICRNL  |
                  LibTermios::IFlag::IXON
    mode.oflag |= LibTermios::OFlag::OPOST
    mode.lflag |= LibTermios::LFlag::ECHO   |
                  LibTermios::LFlag::ECHOE  |
                  LibTermios::LFlag::ECHOK  |
                  LibTermios::LFlag::ECHONL |
                  LibTermios::LFlag::ICANON |
                  LibTermios::LFlag::ISIG   |
                  LibTermios::LFlag::IEXTEN
    LibTermios.tcsetattr(fd, LibTermios::OptionalActions::TCSANOW, pointerof(mode))
  end

  def raw
    preserving_tc_mode("can't set IO#raw") do |mode|
      raw_from_tc_mode!
      yield self
    end
  end

  def raw!
    if LibTermios.tcgetattr(fd, out mode) != 0
      raise Errno.new "can't set IO#raw!"
    end

    raw_from_tc_mode!
  end

  macro raw_from_tc_mode!
    LibTermios.cfmakeraw(pointerof(mode))
    LibTermios.tcsetattr(fd, LibTermios::OptionalActions::TCSANOW, pointerof(mode))
  end

  private def preserving_tc_mode(msg)
    if LibTermios.tcgetattr(fd, out mode) != 0
      raise Errno.new msg
    end
    before = mode
    begin
      yield mode
    ensure
      LibTermios.tcsetattr(fd, LibTermios::OptionalActions::TCSANOW, pointerof(before))
    end
  end

  def read_nonblock(size)
    before = LibC.fcntl(fd, LibC::FCNTL::F_GETFL)
    LibC.fcntl(fd, LibC::FCNTL::F_SETFL, before | LibC::O_NONBLOCK)

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
      LibC.fcntl(fd, LibC::FCNTL::F_SETFL, before)
    end
  end
end
