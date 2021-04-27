module FFI
  # TODO: define well based on architecture
  enum ABI
    FIRST   = 1
    UNIX64
    WIN64
    EFI64   = WIN64
    GNUW64
    LAST
    DEFAULT = UNIX64
  end

  enum Status
    OK          = 0
    BAD_TYPEDEF
    BAD_ABI
  end
end
