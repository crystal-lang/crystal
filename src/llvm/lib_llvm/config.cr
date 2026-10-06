# The list of supported targets are hardcoded in:
# https://github.com/llvm/llvm-project/blob/main/llvm/CMakeLists.txt

lib LibLLVM
  ALL_TARGETS = [
    # default targets (as of LLVM 21)
    "AArch64",
    "AMDGPU",
    "ARM",
    "AVR",
    "BPF",
    "Hexagon",
    "Lanai",
    "LoongArch",
    "MSP430",
    "Mips",
    "NVPTX",
    "PowerPC",
    "RISCV",
    "SPIRV",
    "Sparc",
    "SystemZ",
    "VE",
    "WebAssembly",
    "X86",
    "XCore",

    # experimental targets (as of LLVM 21)
    "ARC",
    "CSKY",
    "DirectX",
    "M68k",
    "Xtensa",
  ]
end
