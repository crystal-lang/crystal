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
    @program.flags << "interpreted"

    @gc_references = [] of Void*

    @defs = {} of Def => CompiledDef
    @defs.compare_by_identity

    @lib_functions = {} of External => LibFunction
    @lib_functions.compare_by_identity

    @dl_handles = {} of String? => Void*

    @symbol_to_index = {} of String => Int32
    @symbols = [] of String

    @multidispatchs = {} of MultidispatchKey => Def

    @ffi_closure_contexts = {} of {UInt64, UInt64} => Interpreter::ClosureContext

    # TODO: finish porting all of LibM instrinsics

    @procs_f32_f32 = {
      :ceil  => Proc(Float32, Float32).new { |a| LibM.ceil_f32(a) },
      :cos   => Proc(Float32, Float32).new { |a| LibM.cos_f32(a) },
      :exp   => Proc(Float32, Float32).new { |a| LibM.exp_f32(a) },
      :exp2  => Proc(Float32, Float32).new { |a| LibM.exp2_f32(a) },
      :floor => Proc(Float32, Float32).new { |a| LibM.floor_f32(a) },
      :log   => Proc(Float32, Float32).new { |a| LibM.log_f32(a) },
      :log2  => Proc(Float32, Float32).new { |a| LibM.log2_f32(a) },
      :log10 => Proc(Float32, Float32).new { |a| LibM.log10_f32(a) },
      :log10 => Proc(Float32, Float32).new { |a| LibM.log10_f32(a) },
      :round => Proc(Float32, Float32).new { |a| LibM.round_f32(a) },
      :rint  => Proc(Float32, Float32).new { |a| LibM.rint_f32(a) },
      :sin   => Proc(Float32, Float32).new { |a| LibM.sin_f32(a) },
      :sqrt  => Proc(Float32, Float32).new { |a| LibM.sqrt_f32(a) },
      :trunc => Proc(Float32, Float32).new { |a| LibM.trunc_f32(a) },
    }

    @procs_f64_f64 = {
      :ceil  => Proc(Float64, Float64).new { |a| LibM.ceil_f64(a) },
      :cos   => Proc(Float64, Float64).new { |a| LibM.cos_f64(a) },
      :exp   => Proc(Float64, Float64).new { |a| LibM.exp_f64(a) },
      :exp2  => Proc(Float64, Float64).new { |a| LibM.exp2_f64(a) },
      :floor => Proc(Float64, Float64).new { |a| LibM.floor_f64(a) },
      :log   => Proc(Float64, Float64).new { |a| LibM.log_f64(a) },
      :log2  => Proc(Float64, Float64).new { |a| LibM.log2_f64(a) },
      :log10 => Proc(Float64, Float64).new { |a| LibM.log10_f64(a) },
      :round => Proc(Float64, Float64).new { |a| LibM.round_f64(a) },
      :rint  => Proc(Float64, Float64).new { |a| LibM.rint_f64(a) },
      :sin   => Proc(Float64, Float64).new { |a| LibM.sin_f64(a) },
      :sqrt  => Proc(Float64, Float64).new { |a| LibM.sqrt_f64(a) },
      :trunc => Proc(Float64, Float64).new { |a| LibM.trunc_f64(a) },
    }

    @constants_memory = Pointer(Void).malloc(1).as(UInt8*)
    @class_vars_memory = Pointer(Void).malloc(1).as(UInt8*)

    # The set of all known interpreters.
    # This set is useful because when we pry inside one interpreter we set
    # all interpreter to that pry mode, so that if a `next` jumps to another
    # fiber or to the C callback handling routine, they are already in pry
    # mode. Existing pry also exists pry from all interpreters.
    @interpreters = Set(Interpreter).new
    @interpreters.compare_by_identity

    @type_instance_var_initializers = {} of Type => Array(CompiledDef)

    @constants = Constants.new(self)
    @class_vars = ClassVars.new(self)
  end

  def add_gc_reference(ref : Reference)
    @gc_references << ref.as(Void*)
  end

  def register_interpreter(interpreter : Interpreter, &)
    register_interpreter(interpreter)
    yield
  ensure
    deregister_interpreter(interpreter)
  end

  def register_interpreter(interpreter : Interpreter)
    @interpreters.add(interpreter)
  end

  def deregister_interpreter(interpreter : Interpreter)
    @interpreters.delete(interpreter)
  end

  # Sets the given pry mode to all known interpreters.
  def pry=(pry : Bool)
    @interpreters.each do |interpreter|
      interpreter.pry_non_recursive = pry
    end
  end

  def ffi_closure_context(interpreter : Interpreter, compiled_def : CompiledDef)
    # Keep the closure contexts in a Hash by the compiled def so we don't
    # lose a reference to it in the GC.
    @ffi_closure_contexts[{interpreter.object_id, compiled_def.object_id}] ||= Interpreter::ClosureContext.new(interpreter, compiled_def)
  end

  def type_instance_var_initializers(type : Type)
    @type_instance_var_initializers[type] ||= begin
      initializers = [] of InstanceVarInitializerContainer::InstanceVarInitializer
      collect_instance_vars_initializers(type, initializers)

      initializers.map do |initializer|
        a_def = create_instance_var_initializer_def(type, initializer)

        compiled_def = CompiledDef.new(self, a_def, a_def.owner, sizeof(Pointer(Void)))
        compiled_def.local_vars.declare("self", type)

        initializer.meta_vars.each do |name, var|
          var_type = var.type?
          next unless var_type

          compiled_def.local_vars.declare(name, var_type)
        end

        compiler = Compiler.new(self, compiled_def, top_level: false)
        compiler.compile_def(a_def)

        if @decompile_defs
          puts "=== #{a_def.name} ==="
          puts Disassembler.disassemble(self, compiled_def)
          puts "=== #{a_def.name} ==="
        end

        compiled_def
      end
    end
  end

  private def collect_instance_vars_initializers(type : ClassType | GenericClassInstanceType, collected) : Nil
    if superclass = type.superclass
      collect_instance_vars_initializers superclass, collected
    end

    collect_instance_vars_initializers_non_recursive type, collected
  end

  private def collect_instance_vars_initializers(type : Type, collected) : Nil
    # Nothing to do
  end

  private def collect_instance_vars_initializers_non_recursive(type : Type, collected) : Nil
    initializers = type.instance_vars_initializers
    collected.concat initializers if initializers
  end

  private def create_instance_var_initializer_def(type : Type, initializer : InstanceVarInitializerContainer::InstanceVarInitializer)
    a_def = Def.new("initialize_#{initializer.name}", args: [Arg.new("self")])
    a_def.body = Assign.new(
      InstanceVar.new(initializer.name),
      initializer.value.clone,
    )

    a_def = program.normalize(a_def)
    a_def.owner = type

    def_args = MetaVars.new
    def_args["self"] = MetaVar.new("self", type)

    visitor = MainVisitor.new(program, def_args, a_def)
    visitor.untyped_def = a_def
    visitor.scope = type
    visitor.path_lookup = type
    # visitor.yield_vars = yield_vars
    # visitor.match_context = match.context
    # visitor.call = self
    a_def.body.accept visitor

    a_def.body = program.cleanup(a_def.body, inside_def: true)
    a_def.type = program.nil_type

    a_def
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

  def const_index_and_compiled_def?(const : Const) : {Int32, CompiledDef}?
    value = constants.fetch?(const)
    if value
      {value.index, value.compiled_def}
    else
      nil
    end
  end

  def declare_class_var(owner : Type, name : String, type : Type, compiled_def : CompiledDef?) : Int32
    class_vars.declare(owner, name, type, compiled_def)
  end

  def class_var_index_and_compiled_def(owner : Type, name : String) : {Int32, CompiledDef?}?
    value = class_vars.fetch?(owner, name)
    if value
      {value.index, value.compiled_def}
    else
      nil
    end
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
