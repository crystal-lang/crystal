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

  def self.int(type, value) : Value
    Value.new LibLLVM.const_int(type, value, 0)
  end

  def self.float(value : Float32) : Value
    Value.new LibLLVM.const_real(LLVM::Float, value)
  end

  def self.float(string : String) : Value
    Value.new LibLLVM.const_real_of_string(LLVM::Float, string)
  end

  def self.double(value : Float64) : Value
    Value.new LibLLVM.const_real(LLVM::Double, value)
  end

  def self.double(string : String) : Value
    Value.new LibLLVM.const_real_of_string(LLVM::Double, string)
  end

  def self.array(type, values : Array(LLVM::Value)) : Value
    Value.new LibLLVM.const_array(type, (values.to_unsafe.as(LibLLVM::ValueRef*)), values.size)
  end

  def self.struct(values : Array(LLVM::Value), packed = false) : Value
    Value.new LibLLVM.const_struct((values.to_unsafe.as(LibLLVM::ValueRef*)), values.size, packed ? 1 : 0)
  end

  def self.string(string) : Value
    Value.new LibLLVM.const_string(string, string.bytesize, 0)
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

  def self.const_inline_asm(type, asm_string, constraints, has_side_effects = false, is_align_stack = false)
    Value.new LibLLVM.const_inline_asm(type, asm_string, constraints, (has_side_effects ? 1 : 0), (is_align_stack ? 1 : 0))
  end

  def self.string_and_dispose(chars) : String
    string = String.new(chars)
    LibLLVM.dispose_message(chars)
    string
  end

  Void   = Type.new LibLLVM.void_type
  Int1   = Type.new LibLLVM.int1_type
  Int8   = Type.new LibLLVM.int8_type
  Int16  = Type.new LibLLVM.int16_type
  Int32  = Type.new LibLLVM.int32_type
  Int64  = Type.new LibLLVM.int64_type
  Float  = Type.new LibLLVM.float_type
  Double = Type.new LibLLVM.double_type

  VoidPointer = Int8.pointer

  {% if flag?(:x86_64) || flag?(:aarch64) %}
    SizeT = Int64
  {% else %}
    SizeT = Int32
  {% end %}
end
