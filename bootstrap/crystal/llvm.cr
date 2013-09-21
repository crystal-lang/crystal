lib LibLLVM("LLVM-3.3")
  type ModuleRef : Void*
  type TypeRef : Void*
  type ValueRef : Void*
  type BasicBlockRef : Void*
  type BuilderRef : Void*
  type ExecutionEngineRef : Void*
  type GenericValueRef : Void*

  enum Linkage
    External,
    AvailableExternally,
    LinkOnceAny,
    LinkOnceODR,
    LinkOnceODRAutoHide,
    WeakAny,
    WeakODR,
    Appending,
    Internal,
    Private,
    DLLImport,
    DLLExport,
    ExternalWeak,
    Ghost,
    Common,
    LinkerPrivate,
    LinkerPrivateWeak
  end

  fun module_create_with_name = LLVMModuleCreateWithName(module_id : Char*) : ModuleRef
  fun dump_module = LLVMDumpModule(module : ModuleRef)
  fun void_type = LLVMVoidType() : TypeRef
  fun function_type = LLVMFunctionType(return_type : TypeRef, param_types : TypeRef*, param_count : Int32, is_var_arg : Int32) : TypeRef
  fun add_function = LLVMAddFunction(module : ModuleRef, name : Char*, type : TypeRef) : ValueRef
  fun get_param = LLVMGetParam(fn : ValueRef, index : Int32) : ValueRef
  fun add_global = LLVMAddGlobal(module : ModuleRef, type : TypeRef, name : Char*) : ValueRef
  fun get_named_function = LLVMGetNamedFunction(mod : ModuleRef, name : Char*) : ValueRef
  fun append_basic_block = LLVMAppendBasicBlock(fn : ValueRef, name : Char*) : BasicBlockRef
  fun create_builder = LLVMCreateBuilder() : BuilderRef
  fun position_builder_at_end = LLVMPositionBuilderAtEnd(builder : BuilderRef, block : BasicBlockRef)
  fun get_insert_block = LLVMGetInsertBlock(builder : BuilderRef) : BasicBlockRef
  fun build_ret_void = LLVMBuildRetVoid(builder : BuilderRef) : ValueRef
  fun build_ret = LLVMBuildRet(builder : BuilderRef, value : ValueRef) : ValueRef
  fun build_br = LLVMBuildBr(builder : BuilderRef, block : BasicBlockRef) : ValueRef
  fun build_call = LLVMBuildCall(builder : BuilderRef, fn : ValueRef, args : ValueRef*, num_args : Int32, name : Char*) : ValueRef
  fun build_alloca = LLVMBuildAlloca(builder : BuilderRef, type : TypeRef, name : Char*) : ValueRef
  fun build_store = LLVMBuildStore(builder : BuilderRef, value : ValueRef, ptr : ValueRef)
  fun build_load = LLVMBuildLoad(builder : BuilderRef, ptr : ValueRef, name : Char*) : ValueRef
  fun build_bit_cast = LLVMBuildBitCast(builder : BuilderRef, value : ValueRef, type : TypeRef, name : Char*) : ValueRef
  fun build_add = LLVMBuildAdd(builder : BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_sub = LLVMBuildSub(builder : BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_mul = LLVMBuildMul(builder : BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_sdiv = LLVMBuildSDiv(builder : BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_fadd = LLVMBuildFAdd(builder : BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_fsub = LLVMBuildFSub(builder : BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_fmul = LLVMBuildFMul(builder : BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_fdiv = LLVMBuildFDiv(builder : BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun int_type = LLVMIntType(bits : Int32) : TypeRef
  fun float_type = LLVMFloatType() : TypeRef
  fun double_type = LLVMDoubleType() : TypeRef
  fun array_type = LLVMArrayType(element_type : TypeRef, count : UInt32) : TypeRef
  fun pointer_type = LLVMPointerType(element_type : TypeRef, address_space : UInt32) : TypeRef
  fun const_int = LLVMConstInt(int_type : TypeRef, value : UInt64, sign_extend : Int32) : ValueRef
  fun const_real_of_string = LLVMConstRealOfString(real_type : TypeRef, value : Char*) : ValueRef
  fun const_string = LLVMConstString(str : Char*, length : UInt32, dont_null_terminate : UInt32) : ValueRef
  fun const_array = LLVMConstArray(element_type : TypeRef, constant_vals : ValueRef*, length : UInt32) : ValueRef
  fun create_jit_compiler_for_module = LLVMCreateJITCompilerForModule (jit : ExecutionEngineRef*, m : ModuleRef, opt_level : Int32, error : Char**) : Int32
  fun run_function = LLVMRunFunction (ee : ExecutionEngineRef, f : ValueRef, num_args : Int32, args : Int32) : GenericValueRef
  fun initialize_x86_target_info = LLVMInitializeX86TargetInfo()
  fun initialize_x86_target = LLVMInitializeX86Target()
  fun initialize_x86_target_mc = LLVMInitializeX86TargetMC()
  fun generic_value_to_int = LLVMGenericValueToInt(value : GenericValueRef, signed : Int32) : Int32
  fun generic_value_to_float = LLVMGenericValueToFloat(type : TypeRef, value : GenericValueRef) : Float64
  fun generic_value_to_pointer = LLVMGenericValueToPointer(value : GenericValueRef) : Void*
  fun write_bitcode_to_file = LLVMWriteBitcodeToFile(module : ModuleRef, path : Char*) : Int32
  fun set_linkage = LLVMSetLinkage(global : ValueRef, linkage : Linkage)
  fun set_global_constant = LLVMSetGlobalConstant(global : ValueRef, is_constant : Int32)
  fun set_initializer = LLVMSetInitializer(global_var : ValueRef, constant_val : ValueRef)
  fun dump_value = LLVMDumpValue(val : ValueRef)
end

module LLVM
  def self.init_x86
    LibLLVM.initialize_x86_target_info
    LibLLVM.initialize_x86_target
    LibLLVM.initialize_x86_target_mc
  end

  def self.dump(value)
    LibLLVM.dump_value value
  end

  class Module
    def initialize(name)
      @module = LibLLVM.module_create_with_name name
      @functions = FunctionCollection.new(self)
      @globals = GlobalCollection.new(self)
    end

    def dump
      LibLLVM.dump_module(@module)
    end

    def functions
      @functions
    end

    def globals
      @globals
    end

    def llvm_module
      @module
    end

    def write_bitcode(filename : String)
      LibLLVM.write_bitcode_to_file @module, filename
    end
  end

  class FunctionCollection
    def initialize(@mod)
    end

    def add(name, arg_types, ret_type)
      args = arg_types.map &.type
      fun_type = LibLLVM.function_type(ret_type.type, args.buffer.as(LibLLVM::TypeRef), arg_types.length, 0)
      func = LibLLVM.add_function(@mod.llvm_module, name, fun_type)
      Function.new(func)
    end

    def [](name)
      func = LibLLVM.get_named_function(@mod.llvm_module, name)
      if func
        Function.new(func)
      else
        raise "Undefined function: #{name}"
      end
    end

    def []?(name)
      func = LibLLVM.get_named_function(@mod.llvm_module, name)
      func.nil? ? nil : Function.new(func)
    end
  end

  class Function
    def initialize(@fun)
    end

    def append_basic_block(name)
      LibLLVM.append_basic_block(@fun, name)
    end

    def llvm_function
      @fun
    end

    def get_param(index)
      LibLLVM.get_param(@fun, index)
    end
  end

  class GlobalCollection
    def initialize(@mod)
    end

    def add(type, name)
      GlobalVariable.new(LibLLVM.add_global(@mod.llvm_module, type.type, name))
    end
  end

  class Value
    getter :value

    def initialize(@value)
    end

    def self.const_string(value)
      new(LibLLVM.const_string(value.cstr, value.length.to_u32, 0_u32))
    end

    def self.const_array(type, values)
      new(LibLLVM.const_array(type.type, values.buffer, values.length.to_u32))
    end
  end

  class GlobalValue < Value
    def linkage=(linkage)
      LibLLVM.set_linkage(@value, linkage)
    end

    def global_constant=(flag : Bool)
      LibLLVM.set_global_constant(@value, flag ? 1 : 0)
    end
  end

  class GlobalVariable < GlobalValue
    def initializer=(value)
      LibLLVM.set_initializer(@value, value.value)
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

    def call(func, args = [] of LibLLVM::ValueRef)
      LibLLVM.build_call(@builder, func.llvm_function, args.buffer, args.length, "")
    end

    def alloca(type, name = "")
      LibLLVM.build_alloca(@builder, type.type, name)
    end

    def store(value, ptr)
      LibLLVM.build_store(@builder, value, ptr)
    end

    def load(ptr, name = "")
      LibLLVM.build_load(@builder, ptr, name)
    end

    def bit_cast(value, type, name = "")
      LibLLVM.build_bit_cast(@builder, value, type.type, name)
    end

    macro self.define_binary(name)"
      def #{name}(lhs, rhs, name = \"\")
        LibLLVM.build_#{name}(@builder, lhs, rhs, name)
      end
    "end

    define_binary add
    define_binary sub
    define_binary mul
    define_binary sdiv
    define_binary fadd
    define_binary fsub
    define_binary fmul
    define_binary fdiv
  end

  abstract class Type
    getter :type

    def initialize(@type)
    end
  end

  class IntType < Type
    def initialize(bits)
      super LibLLVM.int_type(bits)
    end

    def from_i(value)
      LibLLVM.const_int(@type, value.to_u64, 0)
    end
  end

  class FloatType < Type
    def initialize
      super LibLLVM.float_type
    end

    def from_s(value)
      LibLLVM.const_real_of_string(@type, value)
    end
  end

  class DoubleType < Type
    def initialize
      super LibLLVM.double_type
    end

    def from_s(value)
      LibLLVM.const_real_of_string(@type, value)
    end
  end

  class VoidType < Type
    def initialize
      super LibLLVM.void_type
    end
  end

  class ArrayType < Type
    def initialize(element_type : Type, count)
      super LibLLVM.array_type(element_type.type, count.to_u32)
    end
  end

  class PointerType < Type
    def initialize(element_type : Type)
      super LibLLVM.pointer_type(element_type.type, 0_u32)
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

    def to_f32
      LibLLVM.generic_value_to_float(LLVM::Float.type, @value)
    end

    def to_f64
      LibLLVM.generic_value_to_float(LLVM::Double.type, @value)
    end

    def to_string
      LibLLVM.generic_value_to_pointer(@value).as(String)
    end
  end

  class JITCompiler
    def initialize(mod)
      if LibLLVM.create_jit_compiler_for_module(out @jit, mod.llvm_module, 3, out error) != 0
        raise String.from_cstr(error)
      end
    end

    def run_function(func)
      ret = LibLLVM.run_function(@jit, func.llvm_function, 0, 0)
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
