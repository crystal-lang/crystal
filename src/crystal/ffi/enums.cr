module Crystal::FFI
  # TODO: define well based on architecture

  # :nodoc:
  enum ABI
    FIRST   = 1
    UNIX64
    WIN64
    EFI64   = WIN64
    GNUW64
    LAST
    DEFAULT = UNIX64
  end

  # :nodoc:
  enum Status
    OK          = 0
    BAD_TYPEDEF
    BAD_ABI
  end

  # :nodoc:
  enum TypeEnum : UInt16
    VOID       =  0
    INT        =  1
    FLOAT      =  2
    DOUBLE     =  3
    LONGDOUBLE =  4
    UINT8      =  5
    SINT8      =  6
    UINT16     =  7
    SINT16     =  8
    UINT32     =  9
    SINT32     = 10
    UINT64     = 11
    SINT64     = 12
    STRUCT     = 13
    POINTER    = 14
    COMPLEX    = 15
  end
end
