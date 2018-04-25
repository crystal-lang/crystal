require "./codegen"

# Constants are repesented with two LLVM global variables: one has the constant's
# value and the other has a flag that indicates whether the constant was already
# initialized.
#
# When the visitor goes through a `CONST = exp` node (assignment to constant),
# it first checks if the flag is set. If it's not set, it initializes it.
# Otherwise, it does nothing. This is needed because a constant can be read
# before it is declared (hoisting), which is valid because an early pass declares
# constant and the main pass only types them when they are used.
#
# This initialization also detects whether the constant is actually a real constant
# (a number, a string) and then stores that information in the Const type so that
# later reading it is a simple load (doesn't go through the function described below).
#
# When a visitor goes through a `CONST` node (read constant), it first check
# if the flag is set. If it's not set, it initializes it. Then it returns a pointer
# to the global variable. To avoid all this code being generated each time, a function
# is created for each constant and that function is invoked whenever a constant
# need to be read.
#
# In this way we can have main code and constant execute in the order that they
# are defined. Reading a constant before assigning a value to it should be pretty
# rare, but it's still handled here to avoid crashes.
#
# Finally, simple constants like numbers, chars and strings are declared in the
# beginning of the program because they don't involve a complex initialization
# and can be done in any order (they have no side effects).

class Crystal::CodeGenVisitor
  # The special constants ARGC_UNSAFE and ARGV_UNSAFE need to be initialized
  # as soon as the program starts, because we have access to argc and argv
  # in the main function
  def initialize_argv_and_argc
    {"ARGC_UNSAFE", "ARGV_UNSAFE"}.each do |name|
      const = @program.types[name].as(Const)
      global = declare_const(const)
      request_value do
        accept const.value
      end
      store @last, global
      global.initializer = @last.type.null
    end
  end

  def declare_const(const)
    global_name = const.llvm_name
    global = @main_mod.globals[global_name]? ||
             @main_mod.globals.add(@main_llvm_typer.llvm_type(const.value.type), global_name)
    global.linkage = LLVM::Linkage::Internal if @single_module
    global
  end

  def declare_const_initialized_flag(const)
    initialized_flag_name = const.initialized_llvm_name
    initialized_flag = @main_mod.globals[initialized_flag_name]?
    unless initialized_flag
      initialized_flag = @main_mod.globals.add(@main_llvm_context.int1, initialized_flag_name)
      initialized_flag.initializer = @main_llvm_context.int1.const_int(0)
      initialized_flag.linkage = LLVM::Linkage::Internal if @single_module
    end
    initialized_flag
  end

  def declare_const_and_initialized_flag(const)
    {declare_const(const), declare_const_initialized_flag(const)}
  end

  def initialize_simple_const(const)
    global = declare_const(const)
    request_value do
      accept const.value
    end

    const_type = const.value.type
    if const_type.passed_by_value?
      @last = load @last
    end

    global.initializer = @last
    global.global_constant = true

    if const_type.is_a?(PrimitiveType) || const_type.is_a?(EnumType)
      const.initializer = @last
    end
  end

  def initialize_const(const)
    # Maybe the constant was simple and doesn't need a real initialization
    return if const.initializer

    global, initialized_flag = declare_const_and_initialized_flag(const)

    initialized_block, not_initialized_block = new_blocks "initialized", "not_initialized"

    initialized = load(initialized_flag)
    cond initialized, initialized_block, not_initialized_block

    position_at_end not_initialized_block
    store int1(1), initialized_flag

    init_function_name = "~#{const.initialized_llvm_name}"
    func = @main_mod.functions[init_function_name]? || create_initialize_const_function(init_function_name, const)
    func = check_main_fun init_function_name, func
    call func

    br initialized_block

    position_at_end initialized_block

    global
  end

  def create_initialize_const_function(fun_name, const)
    global, initialized_flag = declare_const_and_initialized_flag(const)

    in_main do
      define_main_function(fun_name, ([] of LLVM::Type), llvm_context.void, needs_alloca: true) do |func|
        with_cloned_context do
          # "self" in a constant is the constant's namespace
          context.type = const.namespace

          # Start with fresh variables
          context.vars = LLVMVars.new

          alloca_vars const.vars

          request_value do
            accept const.value
          end

          if const.value.type.passed_by_value?
            @last = load @last
          end

          if @last.constant?
            global.initializer = @last
            global.global_constant = true

            const_type = const.value.type
            if const_type.is_a?(PrimitiveType) || const_type.is_a?(EnumType)
              const.initializer = @last
            end
          else
            global.initializer = llvm_type(const.value.type).null
            store @last, global
          end

          ret
        end
      end
    end
  end

  def read_const(const)
    # We inline constants. Otherwise we use an LLVM const global.
    @last =
      case value = const.compile_time_value
      when Bool   then int1(value ? 1 : 0)
      when Char   then int32(value.ord)
      when Int8   then int8(value)
      when Int16  then int16(value)
      when Int32  then int32(value)
      when Int64  then int64(value)
      when UInt8  then int8(value)
      when UInt16 then int16(value)
      when UInt32 then int32(value)
      when UInt64 then int64(value)
      else
        last = read_const_pointer(const)
        to_lhs last, const.value.type
      end
  end

  def read_const_pointer(const)
    if const == @program.argc || const == @program.argv || const.initializer
      global_name = const.llvm_name
      global = declare_const(const)

      if @llvm_mod != @main_mod
        global = @llvm_mod.globals[global_name]?
        global ||= @llvm_mod.globals.add(llvm_type(const.value.type), global_name)
      end

      return global
    end

    read_function_name = "~#{const.llvm_name}:read"
    func = @main_mod.functions[read_function_name]? || create_read_const_function(read_function_name, const)
    func = check_main_fun read_function_name, func
    @last = call func
    @last
  end

  def create_read_const_function(fun_name, const)
    global, initialized_flag = declare_const_and_initialized_flag(const)

    in_main do
      define_main_function(fun_name, ([] of LLVM::Type), llvm_type(const.value.type).pointer) do |func|
        initialized_block, not_initialized_block = new_blocks "initialized", "not_initialized"

        initialized = load(initialized_flag)
        cond initialized, initialized_block, not_initialized_block

        position_at_end not_initialized_block
        store int1(1), initialized_flag

        init_function_name = "~#{const.initialized_llvm_name}"
        func = @main_mod.functions[init_function_name]? || create_initialize_const_function(init_function_name, const)
        call func

        br initialized_block

        position_at_end initialized_block

        ret global
      end
    end
  end
end
