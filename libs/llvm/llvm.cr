require "./*"

module LLVM
  @@initialized = false

  def self.init_x86
    return if @@initialized
    @@initialized = true

    LibLLVM.initialize_x86_target_info
    LibLLVM.initialize_x86_target
    LibLLVM.initialize_x86_target_mc
    LibLLVM.initialize_x86_asm_printer
    # LibLLVM.link_in_jit
    LibLLVM.link_in_mc_jit
  end

  def self.int(type, value)
    Value.new LibLLVM.const_int(type, value.to_u64, 0)
  end

  def self.float(value : Float32)
    Value.new LibLLVM.const_real(LLVM::Float, value.to_f64)
  end

  def self.float(string : String)
    Value.new LibLLVM.const_real_of_string(LLVM::Float, string)
  end

  def self.double(value : Float64)
    Value.new LibLLVM.const_real(LLVM::Double, value)
  end

  def self.double(string : String)
    Value.new LibLLVM.const_real_of_string(LLVM::Double, string)
  end

  def self.array(type, values : Array(LLVM::Value))
    Value.new LibLLVM.const_array(type, (values.buffer as LibLLVM::ValueRef*), values.length.to_u32)
  end

  def self.struct(values : Array(LLVM::Value), packed = false)
    Value.new LibLLVM.const_struct((values.buffer as LibLLVM::ValueRef*), values.length.to_u32, packed ? 1 : 0)
  end

  def self.string(string)
    Value.new LibLLVM.const_string(string.cstr, string.bytesize.to_u32, 0)
  end

  def self.start_multithreaded
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

  def self.multithreaded?
    LibLLVM.is_multithreaded != 0
  end

  def self.default_target_triple
    chars = LibLLVM.get_default_target_triple
    String.new(chars).tap { LibLLVM.dispose_message(chars) }
  end

  def self.to_io(chars, io)
    io.write Slice.new(chars, C.strlen(chars))
    LibLLVM.dispose_message(chars)
  end

  Void = Type.new LibLLVM.void_type
  Int1 = Type.new LibLLVM.int1_type
  Int8 = Type.new LibLLVM.int8_type
  Int16 = Type.new LibLLVM.int16_type
  Int32 = Type.new LibLLVM.int32_type
  Int64 = Type.new LibLLVM.int64_type
  Float = Type.new LibLLVM.float_type
  Double = Type.new LibLLVM.double_type

  VoidPointer = Int8.pointer

  # TODO: replace with constants after 0.5.0
  ifdef x86_64
    SizeT = Type.new LibLLVM.int64_type # Int64
  else
    SizeT = Type.new LibLLVM.int32_type # Int32
  end
end
