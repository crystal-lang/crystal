require "c/termios"

module Termios
  @[Flags]
  enum InputMode
    BRKINT = LibC::BRKINT
    ICRNL  = LibC::ICRNL
    IGNBRK = LibC::IGNBRK
    IGNCR  = LibC::IGNCR
    IGNPAR = LibC::IGNPAR
    INLCR  = LibC::INLCR
    INPCK  = LibC::INPCK
    ISTRIP = LibC::ISTRIP
    IXANY  = LibC::IXANY
    IXOFF  = LibC::IXOFF
    IXON   = LibC::IXON
    PARMRK = LibC::PARMRK
  end

  {% if flag?(:freebsd) %}
    @[Flags]
    enum OutputMode
      OPOST  = LibC::OPOST
      ONLCR  = LibC::ONLCR
      OCRNL  = LibC::OCRNL
      ONOCR  = LibC::ONOCR
      ONLRET = LibC::ONLRET
      TABDLY = LibC::TABDLY
      TAB0   = LibC::TAB0
      TAB3   = LibC::TAB3
    end
  {% elsif flag?(:openbsd) %}
    @[Flags]
    enum OutputMode
      OPOST  = LibC::OPOST
      ONLCR  = LibC::ONLCR
      OCRNL  = LibC::OCRNL
      ONOCR  = LibC::ONOCR
      ONLRET = LibC::ONLRET
    end
  {% else %}
    @[Flags]
    enum OutputMode
      OPOST  = LibC::OPOST
      ONLCR  = LibC::ONLCR
      OCRNL  = LibC::OCRNL
      ONOCR  = LibC::ONOCR
      ONLRET = LibC::ONLRET
      OFDEL  = LibC::OFDEL
      OFILL  = LibC::OFILL
      CRDLY  = LibC::CRDLY
      CR0    = LibC::CR0
      CR1    = LibC::CR1
      CR2    = LibC::CR2
      CR3    = LibC::CR3
      TABDLY = LibC::TABDLY
      TAB0   = LibC::TAB0
      TAB1   = LibC::TAB1
      TAB2   = LibC::TAB2
      TAB3   = LibC::TAB3
      BSDLY  = LibC::BSDLY
      BS0    = LibC::BS0
      BS1    = LibC::BS1
      VTDLY  = LibC::VTDLY
      VT0    = LibC::VT0
      VT1    = LibC::VT1
      FFDLY  = LibC::FFDLY
      FF0    = LibC::FF0
      FF1    = LibC::FF1
      NLDLY  = LibC::NLDLY
      NL0    = LibC::NL0
      NL1    = LibC::NL1
    end
  {% end %}

  enum BaudRate
    B0     = LibC::B0
    B50    = LibC::B50
    B75    = LibC::B75
    B110   = LibC::B110
    B134   = LibC::B134
    B150   = LibC::B150
    B200   = LibC::B200
    B300   = LibC::B300
    B600   = LibC::B600
    B1200  = LibC::B1200
    B1800  = LibC::B1800
    B2400  = LibC::B2400
    B4800  = LibC::B4800
    B9600  = LibC::B9600
    B19200 = LibC::B19200
    B38400 = LibC::B38400
  end

  enum ControlMode
    CSIZE  = LibC::CSIZE
    CS5    = LibC::CS5
    CS6    = LibC::CS6
    CS7    = LibC::CS7
    CS8    = LibC::CS8
    CSTOPB = LibC::CSTOPB
    CREAD  = LibC::CREAD
    PARENB = LibC::PARENB
    PARODD = LibC::PARODD
    HUPCL  = LibC::HUPCL
    CLOCAL = LibC::CLOCAL
  end

  @[Flags]
  enum LocalMode : Int64
    ECHO   = LibC::ECHO
    ECHOE  = LibC::ECHOE
    ECHOK  = LibC::ECHOK
    ECHONL = LibC::ECHONL
    ICANON = LibC::ICANON
    IEXTEN = LibC::IEXTEN
    ISIG   = LibC::ISIG
    NOFLSH = LibC::NOFLSH
    TOSTOP = LibC::TOSTOP
  end

  @[Flags]
  enum AttributeSelection
    TCSANOW   = LibC::TCSANOW
    TCSADRAIN = LibC::TCSADRAIN
    TCSAFLUSH = LibC::TCSAFLUSH
  end

  enum LineControl
    TCSANOW   = LibC::TCSANOW
    TCSADRAIN = LibC::TCSADRAIN
    TCSAFLUSH = LibC::TCSAFLUSH
    TCIFLUSH  = LibC::TCIFLUSH
    TCIOFLUSH = LibC::TCIOFLUSH
    TCOFLUSH  = LibC::TCOFLUSH
    TCIOFF    = LibC::TCIOFF
    TCION     = LibC::TCION
    TCOOFF    = LibC::TCOOFF
    TCOON     = LibC::TCOON
  end
end
