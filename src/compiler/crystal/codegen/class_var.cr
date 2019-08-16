require "./codegen"

# The logic for class vars is similar to that of constants (in const.cr):
# if a class variable has an initializer, we execute it the moment the codegen
# visits that assignment. We also initialize it with that value if the class
# variable is read. There's an "initialized" flag too.

class Crystal::CodeGenVisitor
  def declare_class_var(class_var : MetaTypeVar)
    global_name = class_var_global_name(class_var)
    global = @main_mod.globals[global_name]?
    unless global
      main_llvm_type = @main_llvm_typer.llvm_type(class_var.type)
      global = @main_mod.globals.add(main_llvm_type, global_name)
      global.linkage = LLVM::Linkage::Internal if @single_module
      global.thread_local = true if class_var.thread_local?
      if !global.initializer && type.includes_type?(@program.nil_type)
        global.initializer = main_llvm_type.null
      end
    end
    global
  end

  def declare_class_var_initialized_flag(class_var : MetaTypeVar)
    initialized_flag_name = class_var_global_initialized_name(class_var)
    initialized_flag = @main_mod.globals[initialized_flag_name]?
    unless initialized_flag
      initialized_flag = @main_mod.globals.add(@main_llvm_context.int1, initialized_flag_name)
      initialized_flag.initializer = @main_llvm_context.int1.const_int(0)
      initialized_flag.linkage = LLVM::Linkage::Internal if @single_module
      initialized_flag.thread_local = true if class_var.thread_local?
    end
    initialized_flag
  end

  def declare_class_var_and_initialized_flag(class_var : MetaTypeVar)
    {declare_class_var(class_var), declare_class_var_initialized_flag(class_var)}
  end

  def declare_class_var_and_initialized_flag_in_this_module(class_var : MetaTypeVar)
    global, initialized_flag = declare_class_var_and_initialized_flag(class_var)
    global = ensure_class_var_in_this_module(global, class_var)
    initialized_flag = ensure_class_var_initialized_flag_in_this_module(initialized_flag, class_var)
    {global, initialized_flag}
  end

  def ensure_class_var_in_this_module(global, class_var)
    if @llvm_mod != @main_mod
      global_name = class_var_global_name(class_var)
      global = @llvm_mod.globals[global_name]?
      unless global
        global = @llvm_mod.globals.add(llvm_type(class_var.type), global_name)
        global.thread_local = true if class_var.thread_local?
      end
    end
    global
  end

  def ensure_class_var_initialized_flag_in_this_module(initialized_flag, class_var)
    if @llvm_mod != @main_mod
      initialized_flag_name = class_var_global_initialized_name(class_var)
      initialized_flag = @llvm_mod.globals[initialized_flag_name]?
      unless initialized_flag
        initialized_flag = @llvm_mod.globals.add(llvm_context.int1, initialized_flag_name)
        initialized_flag.thread_local = true if class_var.thread_local?
      end
    end
    initialized_flag
  end

  def initialize_class_var(class_var : ClassVar)
    initialize_class_var(class_var.var)
  end

  def initialize_class_var(class_var : MetaTypeVar)
    initializer = class_var.initializer

    if initializer
      initialize_class_var(class_var, initializer)
    end
  end

  def initialize_class_var(class_var : MetaTypeVar, initializer : ClassVarInitializer)
    init_func = create_initialize_class_var_function(class_var, initializer)

    # For unsafe class var we just initialize them without
    # using a flag to know if they were initialized
    if class_var.uninitialized? || !init_func
      global = declare_class_var(class_var)
      global = ensure_class_var_in_this_module(global, class_var)
      if init_func
        check_main_fun init_func.name, init_func
        call init_func
      end
      return global
    end

    global, initialized_flag = declare_class_var_and_initialized_flag_in_this_module(class_var)

    initialized_block, not_initialized_block = new_blocks "initialized", "not_initialized"

    initialized = load(initialized_flag)
    cond initialized, initialized_block, not_initialized_block

    position_at_end not_initialized_block
    store int1(1), initialized_flag

    init_func = check_main_fun init_func.name, init_func
    call init_func

    br initialized_block

    position_at_end initialized_block

    global
  end

  def create_initialize_class_var_function(class_var, initializer)
    return nil if class_var.simple_initializer?
    type = class_var.type
    node = initializer.node
    init_function_name = "~#{class_var_global_initialized_name(class_var)}"

    @main_mod.functions[init_function_name]? || begin
      global = declare_class_var(class_var)

      discard = false
      new_func = in_main do
        define_main_function(init_function_name, ([] of LLVM::Type), llvm_context.void, needs_alloca: true) do |func|
          with_cloned_context do
            # "self" in a constant is the class_var owner
            context.type = class_var.owner

            # Start with fresh variables
            context.vars = LLVMVars.new

            alloca_vars initializer.meta_vars

            request_value do
              accept node
            end

            node_type = node.type

            if node_type.nil_type? && !type.nil_type?
              global.initializer = llvm_type(type).null
              discard = true
            elsif @last.constant? && (type.is_a?(PrimitiveType) || type.is_a?(EnumType))
              global.initializer = @last
              discard = true
            else
              global.initializer = llvm_type(type).null
              assign global, type, node.type, @last
            end

            ret
          end
        end
      end

      if discard
        class_var.simple_initializer = true
        new_func.delete
        nil
      else
        new_func
      end
    end
  end

  def read_class_var(node : ClassVar)
    read_class_var(node.var)
  end

  def read_class_var(class_var : MetaTypeVar)
    last = read_class_var_ptr(class_var)
    to_lhs last, class_var.type
  end

  def read_class_var_ptr(node : ClassVar)
    class_var = node.var
    read_class_var_ptr(class_var)
  end

  def read_class_var_ptr(class_var : MetaTypeVar)
    owner = class_var.owner
    case owner
    when VirtualType
      return read_virtual_class_var_ptr(class_var, owner)
    when VirtualMetaclassType
      return read_virtual_metaclass_class_var_ptr(class_var, owner)
    end

    initializer = class_var.initializer
    if !initializer || class_var.uninitialized?
      # Read directly without init flag, but make sure to declare the global in this module too
      return get_class_var_global(class_var)
    end

    initializer = initializer.not_nil!

    func = create_read_class_var_function(class_var, initializer)
    if func
      func = check_main_fun func.name, func
      call func
    else
      get_class_var_global(class_var)
    end
  end

  def get_class_var_global(class_var)
    global_name = class_var_global_name(class_var)
    global = get_global global_name, class_var.type, class_var
    global = ensure_class_var_in_this_module(global, class_var)
    return global
  end

  def read_virtual_class_var_ptr(class_var, owner)
    self_type_id = type_id(llvm_self, owner)
    read_function_name = "~#{class_var_global_name(class_var)}:read"
    func = @main_mod.functions[read_function_name]? ||
           create_read_virtual_class_var_ptr_function(read_function_name, class_var, owner)
    func = check_main_fun read_function_name, func
    call func, self_type_id
  end

  def create_read_virtual_class_var_ptr_function(fun_name, class_var, owner)
    in_main do
      define_main_function(fun_name, [llvm_context.int32], llvm_type(class_var.type).pointer) do |func|
        self_type_id = func.params[0]

        cmp = equal?(self_type_id, type_id(owner.base_type))

        current_type_label, next_type_label = new_blocks "current_type", "next_type"
        cond cmp, current_type_label, next_type_label

        position_at_end current_type_label
        last = read_class_var_ptr(owner.base_type.lookup_class_var(class_var.name))
        ret last

        position_at_end next_type_label

        owner.base_type.all_subclasses.each do |subclass|
          next unless subclass.is_a?(ClassVarContainer)

          cmp = equal?(self_type_id, type_id(subclass))

          current_type_label, next_type_label = new_blocks "current_type", "next_type"
          cond cmp, current_type_label, next_type_label

          position_at_end current_type_label
          last = read_class_var_ptr(subclass.lookup_class_var(class_var.name))
          ret last

          position_at_end next_type_label
        end

        unreachable
      end
    end
  end

  def read_virtual_metaclass_class_var_ptr(class_var, owner)
    self_type_id = type_id(llvm_self, owner)
    read_function_name = "~#{class_var_global_name(class_var)}:read"
    func = @main_mod.functions[read_function_name]? ||
           create_read_virtual_metaclass_var_ptr_function(read_function_name, class_var, owner)
    func = check_main_fun read_function_name, func
    call func, self_type_id
  end

  def create_read_virtual_metaclass_var_ptr_function(fun_name, class_var, owner)
    in_main do
      define_main_function(fun_name, [llvm_context.int32], llvm_type(class_var.type).pointer) do |func|
        self_type_id = func.params[0]

        cmp = equal?(self_type_id, type_id(owner.base_type.metaclass))

        current_type_label, next_type_label = new_blocks "current_type", "next_type"
        cond cmp, current_type_label, next_type_label

        position_at_end current_type_label
        last = read_class_var_ptr(owner.base_type.lookup_class_var(class_var.name))
        ret last

        position_at_end next_type_label

        owner.base_type.instance_type.all_subclasses.each do |subclass|
          next unless subclass.is_a?(ClassVarContainer)

          cmp = equal?(self_type_id, type_id(subclass.metaclass))

          current_type_label, next_type_label = new_blocks "current_type", "next_type"
          cond cmp, current_type_label, next_type_label

          position_at_end current_type_label
          last = read_class_var_ptr(subclass.lookup_class_var(class_var.name))
          ret last

          position_at_end next_type_label
        end
        unreachable
      end
    end
  end

  def create_read_class_var_function(class_var, initializer)
    fun_name = "~#{class_var_global_name(class_var)}:read"
    if func = @main_mod.functions[fun_name]?
      return func
    end

    init_func = create_initialize_class_var_function(class_var, initializer)
    return nil if !init_func

    global, initialized_flag = declare_class_var_and_initialized_flag(class_var)

    in_main do
      define_main_function(fun_name, ([] of LLVM::Type), llvm_type(class_var.type).pointer) do |func|
        initialized_block, not_initialized_block = new_blocks "initialized", "not_initialized"

        initialized = load(initialized_flag)
        cond initialized, initialized_block, not_initialized_block

        position_at_end not_initialized_block
        store int1(1), initialized_flag

        check_main_fun init_func.name, init_func
        call init_func

        br initialized_block

        position_at_end initialized_block

        ret global
      end
    end
  end

  def class_var_global_name(class_var : MetaTypeVar)
    "#{class_var.owner}#{class_var.name.gsub('@', ':')}"
  end

  def class_var_global_initialized_name(class_var : MetaTypeVar)
    "#{class_var.owner}#{class_var.name.gsub('@', ':')}:init"
  end
end
