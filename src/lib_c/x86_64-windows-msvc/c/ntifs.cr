require "c/wdm"

lib LibC
  SYMLINK_FLAG_RELATIVE = 0x00000001

  struct REPARSE_DATA_BUFFER_struct1
    substituteNameOffset : UShort
    substituteNameLength : UShort
    printNameOffset : UShort
    printNameLength : UShort
    flags : ULong
    pathBuffer : WCHAR[1]
  end

  struct REPARSE_DATA_BUFFER_struct2
    substituteNameOffset : UShort
    substituteNameLength : UShort
    printNameOffset : UShort
    printNameLength : UShort
    pathBuffer : WCHAR[1]
  end

  struct REPARSE_DATA_BUFFER_struct3
    dataBuffer : UChar[1]
  end

  union REPARSE_DATA_BUFFER_union
    symbolicLinkReparseBuffer : REPARSE_DATA_BUFFER_struct1
    mountPointReparseBuffer : REPARSE_DATA_BUFFER_struct2
    genericReparseBuffer : REPARSE_DATA_BUFFER_struct3
  end

  struct REPARSE_DATA_BUFFER
    reparseTag : ULong
    reparseDataLength : UShort
    reserved : UShort
    dummyUnionName : REPARSE_DATA_BUFFER_union
  end

  struct FILE_MODE_INFORMATION
    mode : ULONG
  end

  fun NtQueryInformationFile(
    fileHandle : HANDLE,
    ioStatusBlock : IO_STATUS_BLOCK*,
    fileInformation : Void*,
    length : ULONG,
    fileInformationClass : FILE_INFORMATION_CLASS,
  ) : NTSTATUS
end
