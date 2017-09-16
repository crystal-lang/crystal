require "./llvm/**"
require "c/string"

module LLVM
  @@initialized = false

  def self.init_x86
    return if @@initialized_x86
    @@initialized_x86 = true

    {% if LibLLVM::BUILT_TARGETS.includes?(:x86) %}
      LibLLVM.initialize_x86_target_info
      LibLLVM.initialize_x86_target
      LibLLVM.initialize_x86_target_mc
      LibLLVM.initialize_x86_asm_printer
      LibLLVM.initialize_x86_asm_parser
      # LibLLVM.link_in_jit
      LibLLVM.link_in_mc_jit
    {% else %}
      raise "ERROR: LLVM was built without X86 target"
    {% end %}
  end

  def self.init_aarch64
    return if @@initialized_aarch64
    @@initialized_aarch64 = true

    {% if LibLLVM::BUILT_TARGETS.includes?(:aarch64) %}
      LibLLVM.initialize_aarch64_target_info
      LibLLVM.initialize_aarch64_target
      LibLLVM.initialize_aarch64_target_mc
      LibLLVM.initialize_aarch64_asm_printer
      LibLLVM.initialize_aarch64_asm_parser
      # LibLLVM.link_in_jit
      LibLLVM.link_in_mc_jit
    {% else %}
      raise "ERROR: LLVM was built without AArch64 target"
    {% end %}
  end

  def self.init_arm
    return if @@initialized_arm
    @@initialized_arm = true

    {% if LibLLVM::BUILT_TARGETS.includes?(:arm) %}
      LibLLVM.initialize_arm_target_info
      LibLLVM.initialize_arm_target
      LibLLVM.initialize_arm_target_mc
      LibLLVM.initialize_arm_asm_printer
      LibLLVM.initialize_arm_asm_parser
      # LibLLVM.link_in_jit
      LibLLVM.link_in_mc_jit
    {% else %}
      raise "ERROR: LLVM was built without ARM target"
    {% end %}
  end

  def self.start_multithreaded : Bool
    if multithreaded?
      true
    else
      LibLLVM.start_multithreaded != 0
    end
  end

  def self.stop_multithreaded
    if multithreaded?
      LibLLVM.stop_multithreaded
    end
  end

  def self.multithreaded? : Bool
    LibLLVM.is_multithreaded != 0
  end

  def self.default_target_triple : String
    chars = LibLLVM.get_default_target_triple
    triple = string_and_dispose(chars)
    if triple =~ /x86_64-apple-macosx|x86_64-apple-darwin/
      "x86_64-apple-macosx"
    else
      triple
    end
  end

  def self.to_io(chars, io)
    io.write Slice.new(chars, LibC.strlen(chars))
    LibLLVM.dispose_message(chars)
  end

  def self.string_and_dispose(chars) : String
    string = String.new(chars)
    LibLLVM.dispose_message(chars)
    string
  end

  DEBUG_METADATA_VERSION = 3
end
