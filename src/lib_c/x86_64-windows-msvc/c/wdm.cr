require "c/ntstatus"

lib LibC
  struct IO_STATUS_BLOCK__union
    status : NTSTATUS
    pointer : Void*
  end

  struct IO_STATUS_BLOCK
    union : IO_STATUS_BLOCK__union
    information : ULONG*
  end

  enum FILE_INFORMATION_CLASS
    FileModeInformation = 16
  end
end
