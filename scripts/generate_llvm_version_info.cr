#! /usr/bin/env crystal
#
# This script generates the `lib/llvm_VERSION` file from LLVM-C.dll, needed for
# dynamically linking against LLVM on Windows. This is only needed when using an
# LLVM installation different from the one bundled with Crystal.

require "c/libloaderapi"

# The list of supported targets are hardcoded in:
# https://github.com/llvm/llvm-project/blob/main/llvm/CMakeLists.txt
LLVM_ALL_TARGETS = %w(
  AArch64
  AMDGPU
  ARM
  AVR
  BPF
  Hexagon
  Lanai
  LoongArch
  Mips
  MSP430
  NVPTX
  PowerPC
  RISCV
  Sparc
  SystemZ
  VE
  WebAssembly
  X86
  XCore
  ARC
  CSKY
  DirectX
  M68k
  SPIRV
  Xtensa
)

def find_dll_in_env_path
  ENV["PATH"]?.try &.split(Process::PATH_DELIMITER, remove_empty: true) do |path|
    dll_path = File.join(path, "LLVM-C.dll")
    return dll_path if File.exists?(File.join(path, "LLVM-C.dll"))
  end
end

unless dll_fname = ARGV.shift? || find_dll_in_env_path
  abort "Error: Cannot locate LLVM-C.dll, pass its absolute path as a command-line argument or ensure it is available in the PATH environment variable"
end

unless dll = LibC.LoadLibraryExW(dll_fname.check_no_null_byte.to_utf16, nil, 0)
  abort "Error: Failed to load DLL at #{dll_fname}"
end

begin
  unless llvm_get_version = LibC.GetProcAddress(dll, "LLVMGetVersion")
    abort "Error: Failed to resolve LLVMGetVersion"
  end

  llvm_get_version = Proc(LibC::UInt*, LibC::UInt*, LibC::UInt*, Nil).new(llvm_get_version, Pointer(Void).null)
  major = uninitialized LibC::UInt
  minor = uninitialized LibC::UInt
  patch = uninitialized LibC::UInt
  llvm_get_version.call(pointerof(major), pointerof(minor), pointerof(patch))

  targets_built = LLVM_ALL_TARGETS.select do |target|
    LibC.GetProcAddress(dll, "LLVMInitialize#{target}Target") && LibC.GetProcAddress(dll, "LLVMInitialize#{target}TargetInfo")
  end

  # The list of required system libraries are hardcoded in:
  # https://github.com/llvm/llvm-project/blob/main/llvm/lib/Support/CMakeLists.txt
  # There is no way to infer them from `dumpbin /dependents` alone, because that
  # command lists DLLs only, whereas some of these libraries are purely static.
  system_libs = %w(psapi shell32 ole32 uuid advapi32)
  # https://github.com/llvm/llvm-project/commit/a5ffabce98a4b2e9d69009fa3e60f2b154100860
  system_libs << "ws2_32" if {major, minor, patch} >= {18, 0, 0}

  puts "#{major}.#{minor}.#{patch}"
  puts targets_built.join(' ')
  puts system_libs.join(' ', &.+ ".lib")
ensure
  LibC.FreeLibrary(dll)
end
