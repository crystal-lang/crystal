require "./repl"

class Crystal::Repl::Context
  getter program : Program
  getter defs : Hash(Def, CompiledDef)
  getter! constants : Constants
  getter lib_functions : Hash(External, LibFunction)
  getter decompile, trace, stats
  getter procs_f32_f32 : Hash(Symbol, Proc(Float32, Float32))
  getter procs_f64_f64 : Hash(Symbol, Proc(Float64, Float64))

  def initialize(@program : Program, @decompile : Bool, @trace : Bool, @stats : Bool)
    @defs = {} of Def => CompiledDef
    @defs.compare_by_identity

    @lib_functions = {} of External => LibFunction
    @lib_functions.compare_by_identity

    @dl_handles = {} of String? => Void*

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

    @constants = Constants.new(self)
  end

  def declare_const(const : Const, compiled_def : CompiledDef) : Int32
    constants.declare(const, compiled_def)
  end

  def const_index?(const : Const) : Int32?
    constants.const_to_index?(const)
  end

  def sizeof_type(node : ASTNode) : Int32
    type = node.type?
    if type
      sizeof_type(node.type)
    else
      node.raise "BUG: missing type for #{node} (#{node.class})"
    end
  end

  def sizeof_type(type : Type) : Int32
    @program.size_of(type.sizeof_type).to_i32
  end

  def instance_sizeof_type(type : Type) : Int32
    @program.instance_size_of(type.sizeof_type).to_i32
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
end
