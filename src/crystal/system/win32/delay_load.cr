require "c/delayimp"
require "c/heapapi"

lib LibC
  $image_base = __ImageBase : IMAGE_DOS_HEADER
end

private macro p_from_rva(rva)
  pointerof(LibC.image_base).as(UInt8*) + {{ rva }}
end

private macro print_error(format, *args)
  {% if args.empty? %}
    %str = {{ format }}
    LibC.WriteFile(LibC.GetStdHandle(LibC::STD_ERROR_HANDLE), %str, %str.bytesize, out _, nil)
  {% else %}
    %buf = uninitialized LibC::CHAR[1024]
    %args = uninitialized Void*[{{ args.size }}]
    {% for arg, i in args %}
      %args[{{ i }}] = ({{ arg }}).as(Void*)
    {% end %}
    %len = LibC.FormatMessageA(LibC::FORMAT_MESSAGE_FROM_STRING | LibC::FORMAT_MESSAGE_ARGUMENT_ARRAY, {{ format }}, 0, 0, %buf, %buf.size, %args)
    LibC.WriteFile(LibC.GetStdHandle(LibC::STD_ERROR_HANDLE), %buf, %len, out _, nil)
  {% end %}
end

module Crystal::System::DelayLoad
  @[Extern]
  record InternalImgDelayDescr,
    grAttrs : LibC::DWORD,
    szName : LibC::LPSTR,
    phmod : LibC::HMODULE*,
    pIAT : LibC::IMAGE_THUNK_DATA*,
    pINT : LibC::IMAGE_THUNK_DATA*,
    pBoundIAT : LibC::IMAGE_THUNK_DATA*,
    pUnloadIAT : LibC::IMAGE_THUNK_DATA*,
    dwTimeStamp : LibC::DWORD

  @[AlwaysInline]
  def self.pinh_from_image_base(hmod : LibC::HMODULE)
    (hmod.as(UInt8*) + hmod.as(LibC::IMAGE_DOS_HEADER*).value.e_lfanew).as(LibC::IMAGE_NT_HEADERS*)
  end

  @[AlwaysInline]
  def self.interlocked_exchange(atomic : LibC::HMODULE*, value : LibC::HMODULE)
    Atomic::Ops.atomicrmw(:xchg, atomic, value, :sequentially_consistent, false)
  end

  # the functions below work on null-terminated strings; they must not use any C
  # runtime features nor the GC! bang methods may allocate memory

  # returns the length in character units of the null-terminated string *str*
  private def self.strlen(str : LibC::WCHAR*) : Int32
    len = 0
    while str.value != 0
      len &+= 1
      str += 1
    end
    len
  end

  # assigns *src* to *dst*, and returns the end of the new string in *dst*
  private def self.strcpy(dst : LibC::WCHAR*, src : LibC::WCHAR*) : LibC::WCHAR*
    while src.value != 0
      dst.value = src.value
      dst += 1
      src += 1
    end
    dst
  end

  # assigns the concatenation of *args* to the buffer at *buf* with the given
  # *size*, possibly reallocating it, and returns the new buffer
  private def self.strcat(buf : LibC::WCHAR*, size : Int32, *args : *T) : {LibC::WCHAR*, Int32} forall T
    new_size = 1
    {% for i in 0...T.size %}
      %len{i} = strlen(args[{{ i }}])
      new_size &+= %len{i}
    {% end %}
    if new_size > size
      size = new_size
      buf = LibC.HeapReAlloc(LibC.GetProcessHeap, 0, buf, size &* 2).as(LibC::WCHAR*)
    end

    ptr = buf
    {% for i in 0...T.size %}
      ptr = strcpy(ptr, args[{{ i }}])
    {% end %}
    ptr.value = 0

    {buf, size}
  end

  # if *str* starts with *prefix*, returns the substring with *prefix* removed,
  # otherwise returns *str* unmodified
  private def self.str_lchop(str : LibC::WCHAR*, prefix : LibC::WCHAR*) : LibC::WCHAR*
    src = str

    while prefix.value != 0
      return src unless prefix.value == str.value
      prefix += 1
      str += 1
    end

    str
  end

  # given *str*, a normalized absolute path of *size* UTF-16 code units, returns
  # its parent directory by replacing the last directory separator with a null
  # character
  private def self.dirname(str : LibC::WCHAR*, size : Int32)
    ptr = str + size - 1

    # C:\foo.exe -> C:
    # C:\foo\bar.exe -> C:\foo
    # C:\foo\bar\baz.exe -> C:\foo\bar
    while ptr != str
      if ptr.value === '\\'
        ptr.value = 0
        return {str, (ptr - str).to_i32!}
      end
      ptr -= 1
    end

    {str, size}
  end

  # effective returns `::File.dirname(::Process.executable_path).to_utf16`
  private def self.get_origin! : {LibC::WCHAR*, Int32}
    buf = LibC.HeapAlloc(LibC.GetProcessHeap, 0, LibC::MAX_PATH &* 2).as(LibC::WCHAR*)
    len = LibC.GetModuleFileNameW(nil, buf, LibC::MAX_PATH)
    return dirname(buf, len.to_i32!) unless WinError.value.error_insufficient_buffer?

    buf = LibC.HeapReAlloc(LibC.GetProcessHeap, 0, buf, 65534).as(LibC::WCHAR*)
    len = LibC.GetModuleFileNameW(nil, buf, 32767)
    return dirname(buf, len.to_i32!) unless WinError.value.error_insufficient_buffer?

    print_error("FATAL: Failed to get current executable path\n")
    LibC.ExitProcess(1)
  end

  # converts *utf8_str* to a UTF-16 string
  private def self.to_utf16!(utf8_str : LibC::Char*) : LibC::WCHAR*
    utf16_size = LibC.MultiByteToWideChar(LibC::CP_UTF8, 0, utf8_str, -1, nil, 0)
    utf16_str = LibC.HeapAlloc(LibC.GetProcessHeap, 0, utf16_size &* 2).as(LibC::WCHAR*)
    LibC.MultiByteToWideChar(LibC::CP_UTF8, 0, utf8_str, -1, utf16_str, utf16_size)
    utf16_str
  end

  # replaces all instances of "$ORIGIN" in *str* with the directory containing
  # the running executable
  # if "$ORIGIN" is not found, returns *str* unmodified without allocating
  # memory
  private def self.expand_origin!(str : LibC::WCHAR*) : LibC::WCHAR*
    origin_prefix = UInt16.static_array(0x24, 0x4F, 0x52, 0x49, 0x47, 0x49, 0x4E, 0x00) # "$ORIGIN".to_utf16
    ptr = str
    origin = Pointer(LibC::WCHAR).null
    origin_size = 0
    output_size = 1

    while ptr.value != 0
      new_ptr = str_lchop(ptr, origin_prefix.to_unsafe)
      if new_ptr != ptr
        origin, origin_size = get_origin! unless origin
        output_size &+= origin_size
        ptr = new_ptr
        next
      end
      output_size &+= 1
      ptr += 1
    end

    return str unless origin
    output = LibC.HeapAlloc(LibC.GetProcessHeap, 0, output_size &* 2).as(LibC::WCHAR*)
    dst = output
    ptr = str

    while ptr.value != 0
      new_ptr = str_lchop(ptr, origin_prefix.to_unsafe)
      if new_ptr != ptr
        dst = strcpy(dst, origin)
        ptr = new_ptr
        next
      end
      dst.value = ptr.value
      dst += 1
      ptr += 1
    end
    dst.value = 0

    LibC.HeapFree(LibC.GetProcessHeap, 0, origin)
    output
  end

  # `dll` is an ASCII base name without directory separators, e.g. `WS2_32.dll`
  def self.load_library(dll : LibC::Char*) : LibC::HMODULE
    utf16_dll = to_utf16!(dll)

    {% begin %}
      {% paths = Crystal::LIBRARY_RPATH.gsub(/\$\{ORIGIN\}/, "$ORIGIN").split(::Process::PATH_DELIMITER).reject(&.empty?) %}
      {% unless paths.empty? %}
        size = 0x40
        buf = LibC.HeapAlloc(LibC.GetProcessHeap, 0, size &* 2).as(LibC::WCHAR*)

        {% for path, i in paths %}
          # TODO: can this `to_utf16` be done at compilation time?
          root = to_utf16!({{ path.ends_with?("\\") ? path : path + "\\" }}.to_unsafe)
          root_expanded = expand_origin!(root)
          buf, size = strcat(buf, size, root_expanded, utf16_dll)
          handle = LibC.LoadLibraryExW(buf, nil, LibC::LOAD_WITH_ALTERED_SEARCH_PATH)
          LibC.HeapFree(LibC.GetProcessHeap, 0, root_expanded) if root_expanded != root
          LibC.HeapFree(LibC.GetProcessHeap, 0, root)

          if handle
            LibC.HeapFree(LibC.GetProcessHeap, 0, buf)
            LibC.HeapFree(LibC.GetProcessHeap, 0, utf16_dll)
            return handle
          end
        {% end %}

        LibC.HeapFree(LibC.GetProcessHeap, 0, buf)
      {% end %}
    {% end %}

    handle = LibC.LoadLibraryExW(utf16_dll, nil, 0)
    LibC.HeapFree(LibC.GetProcessHeap, 0, utf16_dll)
    handle
  end
end

# This is a port of the default delay-load helper function in the `DelayHlp.cpp`
# file that comes with Microsoft Visual C++, except that all user-defined hooks
# are omitted. It is called every time the program attempts to load a symbol
# from a DLL. For more details see:
# https://learn.microsoft.com/en-us/cpp/build/reference/understanding-the-helper-function
#
# It is available even when the `preview_dll` flag is absent, so that system
# DLLs such as `advapi32.dll` and shards can be delay-loaded in the usual mixed
# static/dynamic builds by passing the appropriate linker flags explicitly.
#
# The delay load helper cannot call functions from the library being loaded, as
# that leads to an infinite recursion. In particular, if `preview_dll` is in
# effect, `Crystal::System.print_error` will not work, because the C runtime
# library DLLs are also delay-loaded and `LibC.snprintf` is unavailable. If you
# want print debugging inside this function, use the `print_error` macro
# instead. Note that its format string is passed to `LibC.FormatMessageA`, which
# uses different conventions from `LibC.printf`.
#
# `kernel32.dll` is the only DLL guaranteed to be available. It cannot be
# delay-loaded and the Crystal compiler excludes it from the linker arguments.
#
# This function does _not_ work with the empty prelude yet!
fun __delayLoadHelper2(pidd : LibC::ImgDelayDescr*, ppfnIATEntry : LibC::FARPROC*) : LibC::FARPROC
  # TODO: support protected delay load? (/GUARD:CF)
  # DloadAcquireSectionWriteAccess

  # Set up some data we use for the hook procs but also useful for our own use
  idd = Crystal::System::DelayLoad::InternalImgDelayDescr.new(
    grAttrs: pidd.value.grAttrs,
    szName: p_from_rva(pidd.value.rvaDLLName).as(LibC::LPSTR),
    phmod: p_from_rva(pidd.value.rvaHmod).as(LibC::HMODULE*),
    pIAT: p_from_rva(pidd.value.rvaIAT).as(LibC::IMAGE_THUNK_DATA*),
    pINT: p_from_rva(pidd.value.rvaINT).as(LibC::IMAGE_THUNK_DATA*),
    pBoundIAT: p_from_rva(pidd.value.rvaBoundIAT).as(LibC::IMAGE_THUNK_DATA*),
    pUnloadIAT: p_from_rva(pidd.value.rvaUnloadIAT).as(LibC::IMAGE_THUNK_DATA*),
    dwTimeStamp: pidd.value.dwTimeStamp,
  )

  dli = LibC::DelayLoadInfo.new(
    cb: sizeof(LibC::DelayLoadInfo),
    pidd: pidd,
    ppfn: ppfnIATEntry,
    szDll: idd.szName,
    dlp: LibC::DelayLoadProc.new,
    hmodCur: LibC::HMODULE.null,
    pfnCur: LibC::FARPROC.null,
    dwLastError: LibC::DWORD.zero,
  )

  if 0 == idd.grAttrs & LibC::DLAttrRva
    # DloadReleaseSectionWriteAccess
    print_error("FATAL: Delay load descriptor does not support RVAs\n")
    LibC.ExitProcess(1)
  end

  hmod = idd.phmod.value

  # Calculate the index for the IAT entry in the import address table
  # N.B. The INT entries are ordered the same as the IAT entries so
  # the calculation can be done on the IAT side.
  iIAT = ppfnIATEntry.as(LibC::IMAGE_THUNK_DATA*) - idd.pIAT
  iINT = iIAT

  pitd = idd.pINT + iINT

  import_by_name = (pitd.value.u1.ordinal & LibC::IMAGE_ORDINAL_FLAG) == 0
  dli.dlp.fImportByName = import_by_name ? 1 : 0

  if import_by_name
    image_import_by_name = p_from_rva(LibC::RVA.new!(pitd.value.u1.addressOfData))
    dli.dlp.union.szProcName = image_import_by_name + offsetof(LibC::IMAGE_IMPORT_BY_NAME, @name)
  else
    dli.dlp.union.dwOrdinal = LibC::DWORD.new!(pitd.value.u1.ordinal & 0xFFFF)
  end

  # Check to see if we need to try to load the library.
  if !hmod
    unless hmod = Crystal::System::DelayLoad.load_library(dli.szDll)
      # DloadReleaseSectionWriteAccess
      print_error("FATAL: Cannot find the DLL named `%1`, exiting\n", dli.szDll)
      LibC.ExitProcess(1)
    end

    # Store the library handle.  If it is already there, we infer
    # that another thread got there first, and we need to do a
    # FreeLibrary() to reduce the refcount
    hmodT = Crystal::System::DelayLoad.interlocked_exchange(idd.phmod, hmod)
    LibC.FreeLibrary(hmod) if hmodT == hmod
  end

  # Go for the procedure now.
  dli.hmodCur = hmod
  if pidd.value.rvaBoundIAT != 0 && pidd.value.dwTimeStamp != 0
    # bound imports exist...check the timestamp from the target image
    pinh = Crystal::System::DelayLoad.pinh_from_image_base(hmod)

    if pinh.value.signature == LibC::IMAGE_NT_SIGNATURE &&
       pinh.value.fileHeader.timeDateStamp == idd.dwTimeStamp &&
       hmod.address == pinh.value.optionalHeader.imageBase
      # Everything is good to go, if we have a decent address
      # in the bound IAT!
      if pfnRet = LibC::FARPROC.new(idd.pBoundIAT[iIAT].u1.function)
        ppfnIATEntry.value = pfnRet
        # DloadReleaseSectionWriteAccess
        return pfnRet
      end
    end
  end

  unless pfnRet = LibC.GetProcAddress(hmod, dli.dlp.union.szProcName)
    # DloadReleaseSectionWriteAccess
    if import_by_name
      print_error("FATAL: Cannot find the symbol named `%1` within `%2`, exiting\n", dli.dlp.union.szProcName, dli.szDll)
    else
      print_error("FATAL: Cannot find the symbol with the ordinal #%1!u! within `%2`, exiting\n", Pointer(Void).new(dli.dlp.union.dwOrdinal), dli.szDll)
    end
    LibC.ExitProcess(1)
  end

  ppfnIATEntry.value = pfnRet
  # DloadReleaseSectionWriteAccess
  pfnRet
end
