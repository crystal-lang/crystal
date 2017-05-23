require "./codegen"

# The logic for class vars is similar to that of constants (in const.cr):
# if a class variable has an initializer, we execute it the moment the codegen
# visits that assignment. We also initialize it with that value if the class
# variable is read. There's an "initialized" flag too.

class Crystal::CodeGenVisitor
  def declare_class_var(owner, name, type, thread_local)
    global_name = class_var_global_name(owner, name)
    global = @main_mod.globals[global_name]?
    unless global
      main_llvm_type = @main_llvm_typer.llvm_type(type)
      global = @main_mod.globals.add(main_llvm_type, global_name)
      global.linkage = LLVM::Linkage::Internal if @single_module
      global.thread_local = true if thread_local
      if !global.initializer && type.includes_type?(@program.nil_type)
        global.initializer = main_llvm_type.null
      end
    end
    global
  end

  def declare_class_var_initialized_flag(owner, name, thread_local)
    initialized_flag_name = class_var_global_initialized_name(owner, name)
    initialized_flag = @main_mod.globals[initialized_flag_name]?
    unless initialized_flag
      initialized_flag = @main_mod.globals.add(@main_llvm_context.int1, initialized_flag_name)
      initialized_flag.initializer = @main_llvm_context.int1.const_int(0)
      initialized_flag.linkage = LLVM::Linkage::Internal if @single_module
      initialized_flag.thread_local = true if thread_local
    end
    initialized_flag
  end

  def declare_class_var_and_initialized_flag(owner, name, type, thread_local)
    {declare_class_var(owner, name, type, thread_local), declare_class_var_initialized_flag(owner, name, thread_local)}
  end

  def declare_class_var_and_initialized_flag_in_this_module(owner, name, type, thread_local)
    global, initialized_flag = declare_class_var_and_initialized_flag(owner, name, type, thread_local)
    global = ensure_class_var_in_this_module(global, owner, name, type, thread_local)
    initialized_flag = ensure_class_var_initialized_flag_in_this_module(initialized_flag, owner, name, thread_local)
    {global, initialized_flag}
  end

  def ensure_class_var_in_this_module(global, owner, name, type, thread_local)
    if @llvm_mod != @main_mod
      global_name = class_var_global_name(owner, name)
      global = @llvm_mod.globals[global_name]?
      unless global
        global = @llvm_mod.globals.add(llvm_type(type), global_name)
        global.thread_local = true if thread_local
      end
    end
    global
  end

  def ensure_class_var_initialized_flag_in_this_module(initialized_flag, owner, name, thread_local)
    if @llvm_mod != @main_mod
      initialized_flag_name = class_var_global_initialized_name(owner, name)
      initialized_flag = @llvm_mod.globals[initialized_flag_name]?
      unless initialized_flag
        initialized_flag = @llvm_mod.globals.add(llvm_context.int1, initialized_flag_name)
        initialized_flag.thread_local = true if thread_local
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
      initialize_class_var(initializer.owner, initializer.name, initializer.meta_vars, initializer.node)
    end
  end

  def initialize_class_var(owner : ClassVarContainer, name : String, meta_vars : MetaVars, node : ASTNode)
    class_var = owner.lookup_class_var(name)

    init_function_name = "~#{class_var_global_initialized_name(owner, name)}"

    # For unsafe class var we just initialize them without
    # using a flag to know if they were initialized
    if class_var.uninitialized?
      global = declare_class_var(owner, name, class_var.type, class_var.thread_local?)
      global = ensure_class_var_in_this_module(global, owner, name, class_var.type, class_var.thread_local?)
      func = @main_mod.functions[init_function_name]? ||
             create_initialize_class_var_function(init_function_name, owner, name, class_var.type, class_var.thread_local?, meta_vars, node)
      func = check_main_fun init_function_name, func
      call func
      return global
    end

    global, initialized_flag = declare_class_var_and_initialized_flag_in_this_module(owner, name, class_var.type, class_var.thread_local?)
    # global, initialized_flag = declare_class_var_and_initialized_flag(owner, name, class_var.type, class_var.thread_local?)

    initialized_block, not_initialized_block = new_blocks "initialized", "not_initialized"

    initialized = load(initialized_flag)
    cond initialized, initialized_block, not_initialized_block

    position_at_end not_initialized_block
    store int1(1), initialized_flag

    func = @main_mod.functions[init_function_name]? ||
           create_initialize_class_var_function(init_function_name, owner, name, class_var.type, class_var.thread_local?, meta_vars, node)
    func = check_main_fun init_function_name, func
    call func

    br initialized_block

    position_at_end initialized_block

    global
  end

  def create_initialize_class_var_function(fun_name, owner, name, type, thread_local, meta_vars, node)
    global = declare_class_var(owner, name, type, thread_local)

    in_main do
      define_main_function(fun_name, ([] of LLVM::Type), llvm_context.void, needs_alloca: true) do |func|
        with_cloned_context do
          # "self" in a constant is the class_var owner
          context.type = owner

          # Start with fresh variables
          context.vars = LLVMVars.new

          alloca_vars meta_vars

          request_value do
            accept node
          end

          node_type = node.type

          if node_type.nil_type? && !type.nil_type?
            global.initializer = llvm_type(type).null
          elsif @last.constant? && (type.is_a?(PrimitiveType) || type.is_a?(EnumType))
            global.initializer = @last
          else
            global.initializer = llvm_type(type).null
            assign global, type, node.type, @last
          end

          ret
        end
      end
    end
  end

  def read_class_var(node : ClassVar)
    class_var = node.var
    read_class_var(node, class_var)
  end

  def read_class_var(node, class_var : MetaTypeVar)
    last = read_class_var_ptr(node, class_var)
    to_lhs last, class_var.type
  end

  def read_class_var_ptr(node : ClassVar)
    class_var = node.var
    read_class_var_ptr(node, class_var)
  end

  def read_class_var_ptr(node, class_var : MetaTypeVar)
    owner = class_var.owner
    case owner
    when VirtualType
      return read_virtual_class_var_ptr(node, class_var, owner)
    when VirtualMetaclassType
      return read_virtual_metaclass_class_var_ptr(node, class_var, owner)
    end

    initializer = class_var.initializer
    if !initializer || class_var.uninitialized?
      # Read directly without init flag, but make sure to declare the global in this module too
      global_name = class_var_global_name(class_var.owner, class_var.name)
      global = get_global global_name, class_var.type, class_var
      global = ensure_class_var_in_this_module(global, class_var.owner, class_var.name, class_var.type, class_var.thread_local?)
      return global
    end

    initializer = initializer.not_nil!

    read_function_name = "~#{class_var_global_name(class_var.owner, class_var.name)}:read"
    func = @main_mod.functions[read_function_name]? ||
           create_read_class_var_function(read_function_name, class_var.owner, class_var.name, class_var.type, class_var.thread_local?, initializer.meta_vars, initializer.node)
    func = check_main_fun read_function_name, func
    call func
  end

  def read_virtual_class_var_ptr(node, class_var, owner)
    self_type_id = type_id(llvm_self, owner)
    read_function_name = "~#{class_var_global_name(owner, class_var.name)}:read"
    func = @main_mod.functions[read_function_name]? ||
           create_read_virtual_class_var_ptr_function(read_function_name, node, class_var, owner)
    func = check_main_fun read_function_name, func
    call func, self_type_id
  end

  def create_read_virtual_class_var_ptr_function(fun_name, node, class_var, owner)
    in_main do
      define_main_function(fun_name, [llvm_context.int32], llvm_type(class_var.type).pointer) do |func|
        self_type_id = func.params[0]

        cmp = equal?(self_type_id, type_id(owner.base_type))

        current_type_label, next_type_label = new_blocks "current_type", "next_type"
        cond cmp, current_type_label, next_type_label

        position_at_end current_type_label
        last = read_class_var_ptr(node, owner.base_type.lookup_class_var(node.name))
        ret last

        position_at_end next_type_label

        owner.base_type.all_subclasses.each do |subclass|
          next unless subclass.is_a?(ClassVarContainer)

          cmp = equal?(self_type_id, type_id(subclass))

          current_type_label, next_type_label = new_blocks "current_type", "next_type"
          cond cmp, current_type_label, next_type_label

          position_at_end current_type_label
          last = read_class_var_ptr(node, subclass.lookup_class_var(node.name))
          ret last

          position_at_end next_type_label
        end

        unreachable
      end
    end
  end

  def read_virtual_metaclass_class_var_ptr(node, class_var, owner)
    self_type_id = type_id(llvm_self, owner)
    read_function_name = "~#{class_var_global_name(owner, class_var.name)}:read"
    func = @main_mod.functions[read_function_name]? ||
           create_read_virtual_metaclass_var_ptr_function(read_function_name, node, class_var, owner)
    func = check_main_fun read_function_name, func
    call func, self_type_id
  end

  def create_read_virtual_metaclass_var_ptr_function(fun_name, node, class_var, owner)
    in_main do
      define_main_function(fun_name, [llvm_context.int32], llvm_type(class_var.type).pointer) do |func|
        self_type_id = func.params[0]

        cmp = equal?(self_type_id, type_id(owner.base_type.metaclass))

        current_type_label, next_type_label = new_blocks "current_type", "next_type"
        cond cmp, current_type_label, next_type_label

        position_at_end current_type_label
        last = read_class_var_ptr(node, owner.base_type.lookup_class_var(node.name))
        ret last

        position_at_end next_type_label

        owner.base_type.instance_type.all_subclasses.each do |subclass|
          next unless subclass.is_a?(ClassVarContainer)

          cmp = equal?(self_type_id, type_id(subclass.metaclass))

          current_type_label, next_type_label = new_blocks "current_type", "next_type"
          cond cmp, current_type_label, next_type_label

          position_at_end current_type_label
          last = read_class_var_ptr(node, subclass.lookup_class_var(node.name))
          ret last

          position_at_end next_type_label
        end
        unreachable
      end
    end
  end

  def create_read_class_var_function(fun_name, owner, name, type, thread_local, meta_vars, node)
    global, initialized_flag = declare_class_var_and_initialized_flag(owner, name, type, thread_local)

    in_main do
      define_main_function(fun_name, ([] of LLVM::Type), llvm_type(type).pointer) do |func|
        initialized_block, not_initialized_block = new_blocks "initialized", "not_initialized"

        initialized = load(initialized_flag)
        cond initialized, initialized_block, not_initialized_block

        position_at_end not_initialized_block
        store int1(1), initialized_flag

        init_function_name = "~#{class_var_global_initialized_name(owner, name)}"
        func = @main_mod.functions[init_function_name]? ||
               create_initialize_class_var_function(init_function_name, owner, name, type, thread_local, meta_vars, node)
        call func

        br initialized_block

        position_at_end initialized_block

        ret global
      end
    end
  end

  def class_var_global_name(owner : Type, name : String)
    "#{owner}#{name.gsub('@', ':')}"
  end

  def class_var_global_initialized_name(owner : Type, name : String)
    "#{owner}#{name.gsub('@', ':')}:init"
  end
end
