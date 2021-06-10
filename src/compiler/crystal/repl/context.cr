require "./repl"

class Crystal::Repl::Context
  record MultidispatchKey, obj_type : Type, call_signature : CallSignature

  getter program : Program
  getter defs : Hash(Def, CompiledDef)
  getter! constants : Constants
  getter! class_vars : ClassVars
  getter lib_functions : Hash(External, LibFunction)
  getter decompile, decompile_defs, trace, stats
  getter procs_f32_f32 : Hash(Symbol, Proc(Float32, Float32))
  getter procs_f64_f64 : Hash(Symbol, Proc(Float64, Float64))
  getter multidispatchs : Hash(MultidispatchKey, Def)

  property constants_memory : Pointer(UInt8)
  property class_vars_memory : Pointer(UInt8)

  def initialize(@program : Program, @decompile : Bool, @decompile_defs : Bool, @trace : Bool, @stats : Bool)
    @gc_references = [] of Void*

    @defs = {} of Def => CompiledDef
    @defs.compare_by_identity

    @lib_functions = {} of External => LibFunction
    @lib_functions.compare_by_identity

    @dl_handles = {} of String? => Void*

    @symbol_to_index = {} of String => Int32
    @symbols = [] of String

    @multidispatchs = {} of MultidispatchKey => Def

    # TODO: finish porting all of LibM instrinsics

    @procs_f32_f32 = {
      :ceil  => Proc(Float32, Float32).new(&.ceil),
      :cos   => Proc(Float32, Float32).new { |a| Math.cos(a) },
      :exp   => Proc(Float32, Float32).new { |a| Math.exp(a) },
      :exp2  => Proc(Float32, Float32).new { |a| Math.exp2(a) },
      :floor => Proc(Float32, Float32).new(&.floor),
      :log   => Proc(Float32, Float32).new { |a| Math.log(a) },
      :log2  => Proc(Float32, Float32).new { |a| Math.log2(a) },
      :log10 => Proc(Float32, Float32).new { |a| Math.log10(a) },
      :log10 => Proc(Float32, Float32).new { |a| Math.log10(a) },
    }

    @procs_f64_f64 = {
      :ceil  => Proc(Float64, Float64).new(&.ceil),
      :cos   => Proc(Float64, Float64).new { |a| Math.cos(a) },
      :exp   => Proc(Float64, Float64).new { |a| Math.exp(a) },
      :exp2  => Proc(Float64, Float64).new { |a| Math.exp2(a) },
      :floor => Proc(Float64, Float64).new(&.floor),
      :log   => Proc(Float64, Float64).new { |a| Math.log(a) },
      :log2  => Proc(Float64, Float64).new { |a| Math.log2(a) },
      :log10 => Proc(Float64, Float64).new { |a| Math.log10(a) },
    }

    @constants_memory = Pointer(Void).malloc(1).as(UInt8*)
    @class_vars_memory = Pointer(Void).malloc(1).as(UInt8*)

    @constants = Constants.new(self)
    @class_vars = ClassVars.new(self)
  end

  def add_gc_reference(ref : Reference)
    @gc_references << ref.as(Void*)
  end

  def symbol_index(symbol : String) : Int32
    # TODO: use a string pool?
    index = @symbol_to_index[symbol]?
    unless index
      index = @symbol_to_index.size
      @symbol_to_index[symbol] = index
      @symbols << symbol
    end
    index
  end

  def index_to_symbol(index : Int32) : String
    @symbols[index]
  end

  def declare_const(const : Const, compiled_def : CompiledDef) : Int32
    constants.declare(const, compiled_def)
  end

  def const_index?(const : Const) : Int32?
    constants.const_to_index?(const)
  end

  def declare_class_var(owner : Type, name : String, type : Type, compiled_def : CompiledDef?) : Int32
    class_vars.declare(owner, name, type, compiled_def)
  end

  def class_var_index?(owner : Type, name : String) : Int32?
    class_vars.key_to_index?(owner, name)
  end

  def aligned_sizeof_type(node : ASTNode) : Int32
    type = node.type?
    if type
      aligned_sizeof_type(node.type)
    else
      node.raise "BUG: missing type for #{node} (#{node.class})"
    end
  end

  def aligned_sizeof_type(type : Type) : Int32
    align(inner_sizeof_type(type))
  end

  def inner_sizeof_type(node : ASTNode) : Int32
    type = node.type?
    if type
      inner_sizeof_type(node.type)
    else
      node.raise "BUG: missing type for #{node} (#{node.class})"
    end
  end

  def inner_sizeof_type(type : Type) : Int32
    @program.size_of(type.sizeof_type).to_i32
  end

  def aligned_instance_sizeof_type(type : Type) : Int32
    align(@program.instance_size_of(type.sizeof_type).to_i32)
  end

  def offset_of(type : Type, index : Int32) : Int32
    @program.offset_of(type.sizeof_type, index).to_i32
  end

  def instance_offset_of(type : Type, index : Int32) : Int32
    @program.instance_offset_of(type.sizeof_type, index).to_i32
  end

  def ivar_offset(type : Type, name : String) : Int32
    ivar_index = type.index_of_instance_var(name).not_nil!

    if type.passed_by_value?
      @program.offset_of(type.sizeof_type, ivar_index).to_i32
    else
      @program.instance_offset_of(type.sizeof_type, ivar_index).to_i32
    end
  end

  def type_id(type : Type) : Int32
    @program.llvm_id.type_id(type)
  end

  def type_from_id(id : Int32) : Type
    @program.llvm_id.type_from_id(id)
  end

  def c_function(lib_type : LibType, name : String)
    # TODO: check lib_type @[Link], lookup library name, etc.
    path = nil
    handle = @dl_handles[path] ||= LibC.dlopen(path, LibC::RTLD_LAZY | LibC::RTLD_GLOBAL)
    if handle.null?
      raise "dlopen failed for lib_type: #{lib_type}"
    end

    fn = LibC.dlsym(handle, name)
    if fn.null?
      raise "dlsym failed for lib: #{lib_type}, name: #{name.inspect}"
    end
    fn
  end

  def align(size : Int32) : Int32
    rem = size.remainder(8)
    if rem == 0
      size
    else
      size + (8 - rem)
    end
  end
end
