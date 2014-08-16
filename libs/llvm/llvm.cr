require "./*"

module LLVM
  def self.init_x86
    LibLLVM.initialize_x86_target_info
    LibLLVM.initialize_x86_target
    LibLLVM.initialize_x86_target_mc
    LibLLVM.initialize_x86_asm_printer
    # LibLLVM.link_in_jit
    LibLLVM.link_in_mc_jit
  end

  def self.dump(value)
    LibLLVM.dump_value value
  end

  def self.type_of(value)
    LibLLVM.type_of(value)
  end

  def self.type_kind_of(value)
    LibLLVM.get_type_kind(value)
  end

  def self.size_of(type)
    LibLLVM.size_of(type)
  end

  def self.constant?(value)
    LibLLVM.is_constant(value) != 0
  end

  def self.null(type)
    LibLLVM.const_null(type)
  end

  def self.pointer_null(type)
    LibLLVM.const_pointer_null(type)
  end

  def self.set_name(value, name)
    LibLLVM.set_value_name(value, name)
  end

  def self.add_attribute(value, attribute)
    LibLLVM.add_attribute value, attribute
  end

  def self.get_attribute(value)
    LibLLVM.get_attribute value
  end

  def self.set_thread_local(value, thread_local = true)
    LibLLVM.set_thread_local(value, thread_local ? 1 : 0)
  end

  def self.undef(type)
    LibLLVM.get_undef(type)
  end

  def self.pointer_type(element_type)
    LibLLVM.pointer_type(element_type, 0_u32)
  end

  def self.function_type(arg_types, return_type, varargs = false)
    LibLLVM.function_type(return_type, arg_types, arg_types.length.to_u32, varargs ? 1 : 0)
  end

  def self.struct_type(name : String, packed = false)
    a_struct = LibLLVM.struct_create_named(Context.global, name)
    element_types = yield a_struct
    LibLLVM.struct_set_body(a_struct, element_types, element_types.length.to_u32, packed ? 1 : 0)
    a_struct
  end

  def self.struct_type(element_types : Array, name = nil, packed = false)
    if name
      struct_type(name, packed) { element_types }
    else
      LibLLVM.struct_type(element_types, element_types.length.to_u32, packed ? 1 : 0)
    end
  end

  def self.array_type(element_type, count)
    LibLLVM.array_type(element_type, count.to_u32)
  end

  def self.int(type, value)
    LibLLVM.const_int(type, value.to_u64, 0)
  end

  def self.float(value : Float32)
    LibLLVM.const_real(LLVM::Float, value.to_f64)
  end

  def self.float(string : String)
    LibLLVM.const_real_of_string(LLVM::Float, string)
  end

  def self.double(value : Float64)
    LibLLVM.const_real(LLVM::Double, value)
  end

  def self.double(string : String)
    LibLLVM.const_real_of_string(LLVM::Double, string)
  end

  def self.set_linkage(value, linkage)
    LibLLVM.set_linkage(value, linkage)
  end

  def self.set_global_constant(value, flag)
    LibLLVM.set_global_constant(value, flag ? 1 : 0)
  end

  def self.array(type, values)
    LibLLVM.const_array(type, values, values.length.to_u32)
  end

  def self.struct(values, packed = false)
    LibLLVM.const_struct(values, values.length.to_u32, packed ? 1 : 0)
  end

  def self.string(string)
    LibLLVM.const_string(string.cstr, string.bytesize.to_u32, 0)
  end

  def self.set_initializer(value, initializer)
    LibLLVM.set_initializer(value, initializer)
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

  def self.first_instruction(block)
    LibLLVM.get_first_instruction(block)
  end

  def self.delete_basic_block(block)
    LibLLVM.delete_basic_block(block)
  end

  Void = LibLLVM.void_type
  Int1 = LibLLVM.int_type(1)
  Int8 = LibLLVM.int_type(8)
  Int16 = LibLLVM.int_type(16)
  Int32 = LibLLVM.int_type(32)
  Int64 = LibLLVM.int_type(64)
  Float = LibLLVM.float_type
  Double = LibLLVM.double_type

  VoidPointer = pointer_type(Int8)

  ifdef x86_64
    SizeT = Int64
  else
    SizeT = Int32
  end
end
