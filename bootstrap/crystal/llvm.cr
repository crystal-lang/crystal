lib LibLLVM("LLVM-3.1")
  type ModuleRef : Void*
  type TypeRef : Void*
  type ValueRef : Void*
  type BasicBlockRef : Void*
  type BuilderRef : Void*
  type ExecutionEngineRef : Void*
  type GenericValueRef : Void*

  fun module_create_with_name = LLVMModuleCreateWithName(module_id : Char*) : ModuleRef
  fun dump_module = LLVMDumpModule(module : ModuleRef)
  fun void_type = LLVMVoidType() : TypeRef
  fun function_type = LLVMFunctionType(return_type : TypeRef, param_types : TypeRef*, param_count : Int, is_var_arg : Int) : TypeRef
  fun add_function = LLVMAddFunction(module : ModuleRef, name : Char*, type : TypeRef) : ValueRef
  fun get_named_function = LLVMGetNamedFunction(mod : ModuleRef, name : Char*) : ValueRef
  fun append_basic_block = LLVMAppendBasicBlock(fn : ValueRef, name : Char*) : BasicBlockRef
  fun create_builder = LLVMCreateBuilder() : BuilderRef
  fun position_builder_at_end = LLVMPositionBuilderAtEnd(builder : BuilderRef, block : BasicBlockRef)
  fun get_insert_block = LLVMGetInsertBlock(builder : BuilderRef) : BasicBlockRef
  fun build_ret_void = LLVMBuildRetVoid(builder : BuilderRef) : ValueRef
  fun build_ret = LLVMBuildRet(builder : BuilderRef, value : ValueRef) : ValueRef
  fun build_br = LLVMBuildBr(builder : BuilderRef, block : BasicBlockRef) : ValueRef
  fun build_call = LLVMBuildCall(builder : BuilderRef, fn : ValueRef, args : ValueRef*, num_args : Int, name : Char*) : ValueRef
  fun int_type = LLVMIntType(bits : Int) : TypeRef
  fun float_type = LLVMFloatType() : TypeRef
  fun double_type = LLVMDoubleType() : TypeRef
  fun const_int = LLVMConstInt(int_type : TypeRef, value : Int, sign_extend : Int) : ValueRef
  fun const_real_of_string = LLVMConstRealOfString(real_type : TypeRef, value : Char*) : ValueRef
  fun create_jit_compiler_for_module = LLVMCreateJITCompilerForModule (jit : out ExecutionEngineRef, m : ModuleRef, opt_level : Int, error : out Char*) : Int
  fun run_function = LLVMRunFunction (ee : ExecutionEngineRef, f : ValueRef, num_args : Int, args : Int) : GenericValueRef
  fun initialize_x86_target_info = LLVMInitializeX86TargetInfo()
  fun initialize_x86_target = LLVMInitializeX86Target()
  fun initialize_x86_target_mc = LLVMInitializeX86TargetMC()
  fun generic_value_to_int = LLVMGenericValueToInt(value : GenericValueRef, signed : Int) : Int
  fun generic_value_to_float = LLVMGenericValueToFloat(type : TypeRef, value : GenericValueRef) : Double
  fun write_bitcode_to_file = LLVMWriteBitcodeToFile(module : ModuleRef, path : Char*) : Int
end

module LLVM
  def self.init_x86
    LibLLVM.initialize_x86_target_info
    LibLLVM.initialize_x86_target
    LibLLVM.initialize_x86_target_mc
  end

  class Module
    def initialize(name)
      @module = LibLLVM.module_create_with_name name
      @functions = FunctionCollection.new(self)
    end

    def dump
      LibLLVM.dump_module(@module)
    end

    def functions
      @functions
    end

    def llvm_module
      @module
    end

    def write_bitcode(filename : String)
      LibLLVM.write_bitcode_to_file @module, filename
    end
  end

  class FunctionCollection
    def initialize(mod)
      @mod = mod
    end

    def add(name, arg_types, ret_type)
      # args = arg_types.map([] of LibLLVM::TypeRef) { |t| t.type }
      args = [] of LibLLVM::TypeRef
      fun_type = LibLLVM.function_type(ret_type.type, args.buffer.as(LibLLVM::TypeRef), arg_types.length, 0)
      fun = LibLLVM.add_function(@mod.llvm_module, name, fun_type)
      Function.new(fun)
    end

    def [](name)
      Function.new(LibLLVM.get_named_function(@mod.llvm_module, name))
    end
  end

  class Function
    def initialize(fun)
      @fun = fun
    end

    def append_basic_block(name)
      LibLLVM.append_basic_block(@fun, name)
    end

    def llvm_function
      @fun
    end
  end

  class Builder
    def initialize
      @builder = LibLLVM.create_builder
    end

    def position_at_end(block)
      LibLLVM.position_builder_at_end(@builder, block)
    end

    def insert_block
      LibLLVM.get_insert_block(@builder)
    end

    def ret
      LibLLVM.build_ret_void(@builder)
    end

    def ret(value)
      LibLLVM.build_ret(@builder, value)
    end

    def br(block)
      LibLLVM.build_br(@builder, block)
    end

    def call(fun)
      LibLLVM.build_call(@builder, fun.llvm_function, nil, 0, "")
    end
  end

  class Type
    attr_reader :type
  end

  class IntType < Type
    def initialize(bits)
      @type = LibLLVM.int_type(bits)
    end

    def from_i(value)
      LibLLVM.const_int(@type, value, 0)
    end
  end

  class FloatType < Type
    def initialize
      @type = LibLLVM.float_type
    end

    def from_s(value)
      LibLLVM.const_real_of_string(@type, value)
    end
  end

  class DoubleType < Type
    def initialize
      @type = LibLLVM.double_type
    end

    def from_s(value)
      LibLLVM.const_real_of_string(@type, value)
    end
  end

  class VoidType < Type
    def initialize
      @type = LibLLVM.void_type
    end
  end

  class GenericValue
    def initialize(value)
      @value = value
    end

    def to_i
      LibLLVM.generic_value_to_int(@value, 1)
    end

    def to_b
      to_i != 0
    end

    def to_f
      LibLLVM.generic_value_to_float(LLVM::Float.type, @value)
    end

    def to_d
      LibLLVM.generic_value_to_float(LLVM::Double.type, @value)
    end
  end

  class JITCompiler
    def initialize(mod)
      if LibLLVM.create_jit_compiler_for_module(out jit, mod.llvm_module, 3, out error) != 0
        raise String.from_cstr(error)
      end
      @jit = jit
    end

    def run_function(fun)
      ret = LibLLVM.run_function(@jit, fun.llvm_function, 0, 0)
      GenericValue.new(ret)
    end
  end

  Void = VoidType.new
  Int1 = IntType.new(1)
  Int8 = IntType.new(8)
  Int16 = IntType.new(16)
  Int32 = IntType.new(32)
  Int64 = IntType.new(64)
  Float = FloatType.new
  Double = DoubleType.new

end
