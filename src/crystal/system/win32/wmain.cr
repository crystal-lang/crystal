require "c/stringapiset"
require "c/winnls"
require "c/stdlib"

# we have both `main` and `wmain`, so we must choose an unambiguous entry point
{% if flag?(:msvc) %}
  @[Link({{ flag?(:static) ? "libcmt" : "msvcrt" }})]
  @[Link(ldflags: "/ENTRY:wmainCRTStartup")]
{% elsif flag?(:gnu) && !flag?(:interpreted) %}
  @[Link(ldflags: "-municode")]
{% end %}
lib LibCrystalMain
end

# The actual entry point for Windows executables.
#
# This is necessary because *argv* (and Win32's `GetCommandLineA`) mistranslate
# non-ASCII characters to Windows-1252, so `PROGRAM_NAME` and `ARGV` would be
# garbled; to avoid that, we use this Windows-exclusive entry point which
# contains the correctly encoded UTF-16 *argv*, convert it to UTF-8, and then
# forward it to the original `main`.
#
# NOTE: we cannot use anything from the standard library here, including the GC.
fun wmain(argc : Int32, argv : UInt16**) : Int32
  utf8_argv = LibC.malloc(sizeof(UInt8*) &* argc).as(UInt8**)
  i = 0_i64
  while i < argc
    arg = (argv + i).value
    utf8_size = LibC.WideCharToMultiByte(LibC::CP_UTF8, 0, arg, -1, nil, 0, nil, nil)
    utf8_arg = LibC.malloc(utf8_size).as(UInt8*)
    LibC.WideCharToMultiByte(LibC::CP_UTF8, 0, arg, -1, utf8_arg, utf8_size, nil, nil)
    (utf8_argv + i).value = utf8_arg
    i &+= 1
  end

  status = main(argc, utf8_argv)

  i = 0_i64
  while i < argc
    LibC.free((utf8_argv + i).value)
    i &+= 1
  end
  LibC.free(utf8_argv)

  # prefer explicit exit over returning the status, so we are free to resume the
  # main thread's fiber on any thread, without occurring a weird behavior where
  # another thread returns from main when the caller might expect the main
  # thread to be the one returning.
  LibC.exit(status)
end
