require "./repl"

# This class contains all of the global data used to interpret a single
# program. For example, it includes the memory region to store constants
# and class variables, what are all the know symbols, and a few more things.
class Crystal::Repl::Context
  record MultidispatchKey, obj_type : Type, call_signature : CallSignature

  getter program : Program

  # A hash of Def to their compiled representation, so we don't compile
  # a single method multiple times.
  # The exceptions are methods with non-captured blocks.
  getter defs : Hash(Def, CompiledDef)

  # Information about all known constants.
  getter! constants : Constants

  # Information about all known class variables.
  getter! class_vars : ClassVars

  # libffi information about external functions.
  getter lib_functions : Hash(External, LibFunction)

  # Cache of multidispatch expansions.
  getter multidispatchs : Hash(MultidispatchKey, Def)

  # The single closure function that we use for all function pointers (procs)
  # passed to C. This closure function knows all the information about
  # the callback being passed, and is able to run the code associated to it.
  getter ffi_closure_fun : LibFFI::ClosureFun

  # The memory where constants are stored. Refer to `Constants` for more on this.
  property constants_memory : Pointer(UInt8)

  # The memory where class vars are stored. Refer to `ClassVars` for more on this.
  property class_vars_memory : Pointer(UInt8)

  # Associated an FFI::Closure's code to a CompiledDef.
  # When we set an extern struct's field that is a Proc, we create
  # an FFI::Closure object and set that instead of a Proc.
  # In case a user reads that field back we need to create a Proc,
  # we can't use an FFI::Closure object. In that case we lookup
  # the proc in this Hash.
  getter ffi_closure_to_compiled_def : Hash(Void*, CompiledDef)

  def initialize(@program : Program)
    @program.flags << "interpreted"

    @gc_references = [] of Void*

    @defs = {} of Def => CompiledDef
    @defs.compare_by_identity

    @lib_functions = {} of External => LibFunction
    @lib_functions.compare_by_identity

    @symbol_to_index = {} of String => Int32
    @symbols = [] of String

    @multidispatchs = {} of MultidispatchKey => Def

    @ffi_closure_contexts = {} of {UInt64, UInt64} => FFIClosureContext

    @constants_memory = Pointer(Void).malloc(1).as(UInt8*)
    @class_vars_memory = Pointer(Void).malloc(1).as(UInt8*)

    @ffi_closure_to_compiled_def = {} of Void* => CompiledDef

    @type_instance_var_initializers = {} of Type => Array(CompiledDef)

    @ffi_closure_fun = LibFFI::ClosureFun.new do |cif, ret, args, user_data|
      Context.ffi_closure_fun(cif, ret, args, user_data)
      nil
    end

    # This is a stack pool, for checkout_stack.
    @stack_pool = Fiber::StackPool.new(protect: false)

    # Mapping of types to numeric ids
    @type_to_id = {} of Type => Int32
    @id_to_type = [] of Type

    @constants = Constants.new(self)
    @class_vars = ClassVars.new(self)

    # Nil has type id 0, String has type id 1
    type_id(@program.nil_type)
    type_id(@program.string)
  end

  getter(throw_value_type : Type) do
    @program.static_array_of(@program.uint8, sizeof(Interpreter::ThrowValue))
  end

  # Many reference values we create when compiling nodes to bytecode
  # must not be collected by the GC. Ideally they should be referenced
  # in the bytecode itself. The problem is that the bytecode isn't
  # always aligned to 8 bytes boundaries. So until we figure out what's
  # the proper way to do it, we just retain these references here.
  def add_gc_reference(ref : Reference)
    @gc_references << ref.as(Void*)
  end

  # Checks out a stack from the stack pool and yields it to the given block.
  # Once the block returns, the stack is returned to the pool.
  # The stack is not cleared after or before it's used.
  def checkout_stack(& : UInt8* -> _)
    stack, _ = @stack_pool.checkout

    begin
      yield stack.as(UInt8*)
    ensure
      @stack_pool.release(stack)
    end
  end

  # This returns the CompiledDef that corresponds to __crystal_raise_overflow
  getter(crystal_raise_overflow_compiled_def : CompiledDef) do
    call = Call.new(nil, "__crystal_raise_overflow", global: true)
    program.semantic(call)

    local_vars = LocalVars.new(self)
    compiler = Compiler.new(self, local_vars)
    compiler.compile(call)

    defs[call.target_def]
  end

  record InstanceVarInitializer,
    initializer : InstanceVarInitializerContainer::InstanceVarInitializer,
    owner : Type

  def type_instance_var_initializers(type : Type)
    @type_instance_var_initializers[type] ||= begin
      initializers = [] of InstanceVarInitializer
      collect_instance_vars_initializers(type, initializers)

      initializers.map do |initializer|
        a_def = create_instance_var_initializer_def(type, initializer)

        compiled_def = CompiledDef.new(self, a_def, a_def.owner, sizeof(Pointer(Void)))
        compiled_def.local_vars.declare("self", type)

        initializer.initializer.meta_vars.each do |name, var|
          var_type = var.type?
          next unless var_type

          compiled_def.local_vars.declare(name, var_type)
        end

        compiler = Compiler.new(self, compiled_def, top_level: false)
        compiler.compile_def(compiled_def)

        {% if Debug::DECOMPILE %}
          puts "=== #{a_def.name} ==="
          puts Disassembler.disassemble(self, compiled_def)
          puts "=== #{a_def.name} ==="
        {% end %}

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
    initializers.try &.each do |initializer|
      collected << InstanceVarInitializer.new(initializer, type)
    end
  end

  private def create_instance_var_initializer_def(type : Type, initializer : InstanceVarInitializer)
    # Creates a def that will assign the initializer's value to the instance variable.
    # The initializer's value is fully typed already, so we don't need to type it
    # again. We can just create the assignment and type those nodes for the
    # interpreter compiler to be able to compile it.
    value = initializer.initializer.value

    ivar = InstanceVar.new(initializer.initializer.name)
    ivar.type = value.type

    assign = Assign.new(ivar, value)
    assign.type = value.type

    a_def = Def.new("initialize_#{initializer.initializer.name}", args: [Arg.new("self", type: type)])
    a_def.body = assign
    a_def.type = program.nil_type
    a_def.owner = type

    vars = initializer.initializer.meta_vars.clone
    vars["self"] = MetaVar.new("self", type)
    a_def.vars = vars

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

  def ffi_closure_context(interpreter : Interpreter, compiled_def : CompiledDef)
    # Keep the closure contexts in a Hash by the compiled def so we don't
    # lose a reference to it in the GC.
    @ffi_closure_contexts[{interpreter.object_id, compiled_def.object_id}] ||= FFIClosureContext.new(interpreter, compiled_def)
  end

  protected def self.ffi_closure_fun(cif : LibFFI::Cif*, ret : Void*, args : Void**, user_data : Void*)
    # This is the generic callback that gets called on any C callback.
    closure_context = user_data.as(FFIClosureContext)
    interpreter = closure_context.interpreter
    compiled_def = closure_context.compiled_def

    # What to do:
    #   - create a new interpreter that uses the same stack
    #     (call the second initialize overload)
    #   - copy args into the stack, starting from stack_top
    #   - call interpret on the compiled_def.def.body
    #   - copy the value back to ret

    interpreter.context.checkout_stack do |stack|
      stack_top = stack

      # Clear the proc's local vars area, the stack might have garbage there
      stack_top.clear(compiled_def.local_vars.max_bytesize)

      compiled_def.def.args.each_with_index do |arg, i|
        args[i].as(UInt8*).copy_to(stack_top, interpreter.inner_sizeof_type(arg.type))
        stack_top += interpreter.aligned_sizeof_type(arg.type)
      end

      # TODO: maybe we don't need a new interpreter for this?
      sub_interpreter = Interpreter.new(interpreter, compiled_def, stack, 0)

      value = sub_interpreter.interpret(compiled_def.def.body, compiled_def.def.vars.not_nil!)

      value.copy_to(ret.as(UInt8*))
    end
  end

  def aligned_sizeof_type(node : ASTNode) : Int32
    aligned_sizeof_type(node.type?)
  end

  def aligned_sizeof_type(type : Type) : Int32
    align(inner_sizeof_type(type))
  end

  def aligned_sizeof_type(type : Nil) : Int32
    0
  end

  def inner_sizeof_type(node : ASTNode) : Int32
    inner_sizeof_type(node.type?)
  end

  def inner_sizeof_type(type : Type) : Int32
    @program.size_of(type.sizeof_type).to_i32
  end

  def inner_sizeof_type(type : Nil) : Int32
    0
  end

  def inner_alignof_type(node : ASTNode) : Int32
    inner_alignof_type(node.type?)
  end

  def inner_alignof_type(type : Type) : Int32
    @program.align_of(type.sizeof_type).to_i32
  end

  def inner_alignof_type(type : Nil) : Int32
    0
  end

  def aligned_instance_sizeof_type(type : Type) : Int32
    align(inner_instance_sizeof_type(type))
  end

  def inner_instance_sizeof_type(node : ASTNode) : Int32
    inner_instance_sizeof_type(node.type?)
  end

  def inner_instance_sizeof_type(type : Type) : Int32
    @program.instance_size_of(type.sizeof_type).to_i32
  end

  def inner_instance_sizeof_type(type : Nil) : Int32
    0
  end

  def inner_instance_alignof_type(node : ASTNode) : Int32
    inner_instance_alignof_type(node.type?)
  end

  def inner_instance_alignof_type(type : Type) : Int32
    @program.instance_align_of(type.sizeof_type).to_i32
  end

  def inner_instance_alignof_type(type : Nil) : Int32
    0
  end

  def offset_of(type : Type, index : Int32) : Int32
    @program.offset_of(type.sizeof_type, index).to_i32
  end

  def instance_offset_of(type : Type, index : Int32) : Int32
    @program.instance_offset_of(type.sizeof_type, index).to_i32
  end

  def ivar_offset(type : Type, name : String) : Int32
    ivar_index = type.index_of_instance_var(name).not_nil!

    if type.is_a?(VirtualType) && type.struct? && type.abstract?
      # If the type is a virtual abstract struct then the type
      # is actually represented as {type_id, value} so the offset
      # of the instance var is behind type_id, which is 8 bytes
      @program.offset_of(type.base_type, ivar_index).to_i32 + 8
    elsif type.passed_by_value?
      @program.offset_of(type.sizeof_type, ivar_index).to_i32
    else
      @program.instance_offset_of(type.sizeof_type, ivar_index).to_i32
    end
  end

  def type_id(type : Type) : Int32
    id = @type_to_id[type]?
    unless id
      id = @id_to_type.size
      @id_to_type << type
      @type_to_id[type] = id
    end
    id
  end

  def type_from_id(id : Int32) : Type
    @id_to_type[id]
  end

  getter? loader : Loader?

  getter(loader : Loader) {
    lib_flags = program.lib_flags
    # Execute and expand `subcommands`.
    lib_flags = lib_flags.gsub(/`(.*?)`/) { `#{$1}`.chomp }

    args = Process.parse_arguments(lib_flags)
    # FIXME: Part 1: This is a workaround for initial integration of the interpreter:
    # The loader can't handle the static libgc.a usually shipped with crystal and loading as a shared library conflicts
    # with the compiler's own GC.
    # (Windows doesn't seem to have this issue)
    unless program.has_flag?("win32") && program.has_flag?("gnu")
      args.delete("-lgc")
    end

    # recreate the MSVC developer prompt environment, similar to how compiled
    # code does it in `Compiler#linker_command`
    if program.has_flag?("msvc")
      _, link_args = program.msvc_compiler_and_flags
      args.concat(link_args)
    end

    Crystal::Loader.parse(args, dll_search_paths: dll_search_paths).tap do |loader|
      # FIXME: Part 2: This is a workaround for initial integration of the interpreter:
      # We append a handle to the current executable (i.e. the compiler program)
      # to the loader's handle list. This gives the loader access to all the symbols in the compiler program,
      # including those from statically linked libraries like libgc.
      # This probably won't work for a fully statically linked compiler.
      # But `Crystal::Loader` currently doesn't support that anyways.
      loader.load_current_program_handle

      if ENV["CRYSTAL_INTERPRETER_LOADER_INFO"]?.presence
        STDERR.puts "Crystal::Loader loaded libraries:"
        loader.loaded_libraries.each do |path|
          STDERR.puts "      #{path}"
        end
      end
    end
  }

  # Extra DLL search paths to mimic compiled code's DLL-copying behavior
  # regarding `@[Link]` annotations. These directories should match the ones
  # used in `Crystal::Program#each_dll_path`
  private def dll_search_paths
    {% if flag?(:msvc) %}
      paths = CrystalLibraryPath.default_paths

      if executable_path = Process.executable_path
        paths << File.dirname(executable_path)
      end

      ENV["PATH"]?.try &.split(Process::PATH_DELIMITER, remove_empty: true) do |path|
        paths << path
      end

      paths
    {% else %}
      nil
    {% end %}
  end

  def c_function(name : String)
    loader.find_symbol(name)
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
