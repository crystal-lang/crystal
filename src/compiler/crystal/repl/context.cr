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

  @pkg_config_path : String?

  def initialize(@program : Program)
    @program.flags << "interpreted"

    @gc_references = [] of Void*

    @defs = {} of Def => CompiledDef
    @defs.compare_by_identity

    @lib_functions = {} of External => LibFunction
    @lib_functions.compare_by_identity

    @dl_handles = {} of LibType => Void*

    @symbol_to_index = {} of String => Int32
    @symbols = [] of String

    @multidispatchs = {} of MultidispatchKey => Def

    @ffi_closure_contexts = {} of {UInt64, UInt64} => FFIClosureContext

    # TODO: finish porting all of LibM instrinsics

    @constants_memory = Pointer(Void).malloc(1).as(UInt8*)
    @class_vars_memory = Pointer(Void).malloc(1).as(UInt8*)

    @ffi_closure_to_compiled_def = {} of Void* => CompiledDef

    @type_instance_var_initializers = {} of Type => Array(CompiledDef)

    @ffi_closure_fun = LibFFI::ClosureFun.new do |cif, ret, args, user_data|
      Context.ffi_closure_fun(cif, ret, args, user_data)
      nil
    end

    @pkg_config_path = Process.find_executable("pkg-config")

    # This is a stack pool, for checkout_stack.
    @stack_pool = [] of UInt8*

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
    if @stack_pool.empty?
      stack = Pointer(Void).malloc(8 * 1024 * 1024).as(UInt8*)
    else
      stack = @stack_pool.pop
    end

    begin
      yield stack
    ensure
      @stack_pool.push(stack)
    end
  end

  # This returns the CompiledDef that correspnds to __crystal_raise_overflow
  getter(crystal_raise_overflow_compiled_def : CompiledDef) do
    call = Call.new(nil, "__crystal_raise_overflow", global: true)
    program.semantic(call)

    local_vars = LocalVars.new(self)
    compiler = Compiler.new(self, local_vars)
    compiler.compile(call)

    defs[call.target_def]
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

  def c_function(lib_type : LibType, name : String)
    handle = lib_type_handle(lib_type)
    unless handle
      raise "Can't find dynamic library for #{lib_type}"
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

  private def lib_type_handle(lib_type)
    pkg_config_path = @pkg_config_path

    handle = @dl_handles[lib_type]?
    return handle if handle

    lib_type.link_annotations.try &.each do |link_annotation|
      if ld_flags = link_annotation.ldflags
        if ld_flags.starts_with?('`') && ld_flags.ends_with?('`')
          handle = handle_from_ld_flags_command(ld_flags[1...-1])
        else
          handle = handle_from_ld_flags(ld_flags)
        end
      elsif (pkg_config_name = link_annotation.pkg_config) && pkg_config_path
        handle = handle_from_pkg_config(pkg_config_path, pkg_config_name)
      elsif (lib_name = link_annotation.lib) && pkg_config_path
        handle = handle_from_pkg_config(pkg_config_path, lib_name)
      end

      break if handle
    end

    # If we can't find a handle, let's use one for the current binary
    unless handle
      handle = LibC.dlopen(nil, LibC::RTLD_LAZY | LibC::RTLD_GLOBAL)
      handle = nil if handle.null?
    end

    @dl_handles[lib_type] = handle if handle

    handle
  end

  # Returns the result of running `pkg-config mod` but returns nil if
  # the module does not exist.
  private def pkg_config(pkg_config_path : String, mod : String) : String?
    return unless (Process.run(pkg_config_path, {mod}).success? rescue nil)

    args = ["--libs"]
    args << mod

    process = Process.new(pkg_config_path, args, input: :close, output: :pipe, error: :inherit)
    flags = process.output.gets_to_end.chomp
    status = process.wait
    return unless status.success?

    flags
  end

  private def handle_from_pkg_config(pkg_config_path, pkg_config_name)
    ld_flags = pkg_config(pkg_config_path, pkg_config_name)
    return unless ld_flags

    handle_from_ld_flags(ld_flags)
  end

  private def handle_from_ld_flags_command(command : String)
    process = Process.new(command, shell: true, output: :pipe)
    output = process.output.gets_to_end.chomp
    status = process.wait
    return unless status.success?

    handle_from_ld_flags(output)
  end

  private def handle_from_ld_flags(flags : String)
    # I don't know if this is the correct way to do this, but it works!
    # For example:
    #
    # ```
    # $ pkg-config --libs gmp
    # -L/usr/local/Cellar/gmp/6.2.1/lib -lgmp
    # ```
    #
    # So, in Mac we search for a file named
    # /usr/local/Cellar/gmp/6.2.1/lib/libgmp.dylib
    args = Process.parse_arguments(flags)

    path = nil
    name = nil

    args.each do |arg|
      if piece = arg.lchop?("-L")
        path = piece
      elsif piece = arg.lchop?("-l")
        name = piece
      end
    end

    return unless path && name

    # TODO: obviously support other platforms than darwin
    lib_path = File.join(path, "lib#{name}.dylib")
    return unless File.exists?(lib_path)

    handle = LibC.dlopen(lib_path, LibC::RTLD_LAZY | LibC::RTLD_GLOBAL)
    return if handle.null?

    handle
  end
end
