require "./codegen"

# The logic for class vars is similar to that of constants (in const.cr):
# if a class variable has an initializer, we execute it the moment the codegen
# visits that assignment. We also initialize it with that value if the class
# variable is read. There's an "initialized" flag too.

class Crystal::CodeGenVisitor
  def declare_class_var(class_var)
    global_name = class_var_global_name(class_var)
    global = @main_mod.globals[global_name]? ||
      @main_mod.globals.add(llvm_type(class_var.type), global_name)
    global.linkage = LLVM::Linkage::Internal if @single_module
    global.thread_local = true if class_var.thread_local?
    global
  end

  def declare_class_var_initialized_flag(class_var)
    initialized_flag_name = class_var_global_initialized_name(class_var)
    initialized_flag = @main_mod.globals[initialized_flag_name]?
    unless initialized_flag
      initialized_flag = @main_mod.globals.add(LLVM::Int1, initialized_flag_name)
      initialized_flag.initializer = int1(0)
      initialized_flag.linkage = LLVM::Linkage::Internal if @single_module
      initialized_flag.thread_local = true if class_var.thread_local?
    end
    initialized_flag
  end

  def declare_class_var_and_initialized_flag(class_var)
    {declare_class_var(class_var), declare_class_var_initialized_flag(class_var)}
  end

  def initialize_class_var(class_var : ClassVar)
    initialize_class_var(class_var.var)
  end

  def initialize_class_var(class_var : MetaTypeVar)
    initializer = class_var.initializer
    initialize_class_var(initializer) if initializer
  end

  def initialize_class_var(initializer : ClassVarInitializer)
    class_var = initializer.owner.class_vars[initializer.name]
    global, initialized_flag = declare_class_var_and_initialized_flag(class_var)

    initialized_block, not_initialized_block = new_blocks "initialized", "not_initialized"

    initialized = load(initialized_flag)
    cond initialized, initialized_block, not_initialized_block

    position_at_end not_initialized_block
    store int1(1), initialized_flag

    init_function_name = "~#{class_var_global_initialized_name(class_var)}"
    func = @main_mod.functions[init_function_name]? || create_initialize_class_var_function(init_function_name, class_var)
    func = check_main_fun init_function_name, func
    call func

    br initialized_block

    position_at_end initialized_block

    global
  end

  def create_initialize_class_var_function(fun_name, class_var)
    global, initialized_flag = declare_class_var_and_initialized_flag(class_var)
    initializer = class_var.initializer.not_nil!

    define_main_function(fun_name, ([] of LLVM::Type), LLVM::Void, needs_alloca: true) do |func|
      with_cloned_context do
        # "self" in a constant is the class_var owner
        context.type = class_var.owner

        # Start with fresh variables
        context.vars = LLVMVars.new

        alloca_vars initializer.meta_vars

        request_value do
          accept initializer.node
        end

        node_type = initializer.node.type

        if node_type.nil_type? && !class_var.type.nil_type?
          global.initializer = llvm_type(class_var.type).null
        elsif @last.constant? && (class_var.type.is_a?(PrimitiveType) || class_var.type.is_a?(EnumType))
          global.initializer = @last
        else
          if class_var.type.passed_by_value?
            global.initializer = llvm_type(class_var.type).undef
          else
            global.initializer = llvm_type(class_var.type).null
          end
          assign global, class_var.type, initializer.node.type, @last
        end

        ret
      end
    end
  end

  def read_class_var(node : ClassVar)
    class_var = node.var
    initializer = class_var.initializer
    unless initializer
      return read_global class_var_global_name(node.var), node.type, node.var
    end

    read_function_name = "~#{class_var_global_name(class_var)}:read"
    func = @main_mod.functions[read_function_name]? || create_read_class_var_function(read_function_name, class_var)
    func = check_main_fun read_function_name, func
    @last = call func
    @last = to_lhs @last, class_var.type
  end

  def create_read_class_var_function(fun_name, class_var)
    global, initialized_flag = declare_class_var_and_initialized_flag(class_var)

    define_main_function(fun_name, ([] of LLVM::Type), llvm_type(class_var.type).pointer) do |func|
      initialized_block, not_initialized_block = new_blocks "initialized", "not_initialized"

      initialized = load(initialized_flag)
      cond initialized, initialized_block, not_initialized_block

      position_at_end not_initialized_block
      store int1(1), initialized_flag

      init_function_name = "~#{class_var_global_initialized_name(class_var)}"
      func = @main_mod.functions[init_function_name]? || create_initialize_class_var_function(init_function_name, class_var)
      call func

      br initialized_block

      position_at_end initialized_block

      ret global
    end
  end

  def class_var_global_name(node)
    "#{node.owner}#{node.name.gsub('@', ':')}"
  end

  def class_var_global_initialized_name(node)
    "#{node.owner}#{node.name.gsub('@', ':')}:init"
  end
end
