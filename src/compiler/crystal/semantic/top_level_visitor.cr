require "./semantic_visitor"

# In this pass we traverse the AST nodes to declare and process:
# - class
# - struct
# - module
# - include
# - extend
# - enum (checking their value, since these need to be numbers or simple math operations)
# - macro
# - def (without going inside them)
# - alias (without resolution)
# - constants (without checking their value)
# - macro calls (only surface macros, because we don't go inside defs)
# - lib and everything inside them
# - fun with body (without going inside them)
#
# Macro calls are expanded, but only the first pass is done to them. This
# allows macros to define new classes and methods.
#
# We also process @[Link] attributes.
#
# After this pass we have completely defined the whole class hierarchy,
# including methods. After this point no new classes or methods can be introduced
# since in next passes we only go inside methods and top-level code, but we already
# analyzed top-level (surface) macros that could have expanded to class/method
# definitions.
#
# Now that we know the whole hierarchy, when someone types Foo, we know whether Foo has
# subclasses or not and we can tag it as "virtual" (having subclasses), but that concept
# might disappear in the future and we'll make consider everything as "maybe virtual".
class Crystal::TopLevelVisitor < Crystal::SemanticVisitor
  ValidDefAttributes       = %w(AlwaysInline Naked NoInline Raises ReturnsTwice Primitive)
  ValidFunDefAttributes    = %w(AlwaysInline Naked NoInline Raises ReturnsTwice CallConvention)
  ValidStructDefAttributes = %w(Packed)
  ValidEnumDefAttributes   = %w(Flags)

  # These are `new` methods (expanded) that was created from `initialize` methods (original)
  getter new_expansions = [] of {original: Def, expanded: Def}

  # All finished hooks and their scope
  record FinishedHook, scope : ModuleType, macro : Macro
  @finished_hooks = [] of FinishedHook

  @last_doc : String?

  def visit(node : ClassDef)
    check_outside_exp node, "declare class"

    scope, name, type = lookup_type_def(node)

    created_new_type = false
    extern = false
    extern_union = false
    packed = false

    if node.struct?
      extern, extern_union, packed = process_class_def_struct_attributes
    else
      if (attributes = @attributes) && !attributes.empty?
        node.raise "class declaration can't have attributes"
      end
    end

    if type
      type = type.remove_alias

      unless type.is_a?(ClassType)
        node.raise "#{name} is not a #{node.struct? ? "struct" : "class"}, it's a #{type.type_desc}"
      end

      if node.struct? != type.struct?
        node.raise "#{name} is not a #{node.struct? ? "struct" : "class"}, it's a #{type.type_desc}"
      end

      if type_vars = node.type_vars
        if type.is_a?(GenericType)
          type_type_vars = type.type_vars
          if type_vars != type_type_vars
            if type_type_vars.size == 1
              node.raise "type var must be #{type_type_vars.join ", "}, not #{type_vars.join ", "}"
            else
              node.raise "type vars must be #{type_type_vars.join ", "}, not #{type_vars.join ", "}"
            end
          end
        else
          node.raise "#{name} is not a generic #{type.type_desc}"
        end
      end

      if extern && type.is_a?(NonGenericClassType)
        type.extern = true
        type.extern_union = extern_union
        type.packed = packed
      end
    else
      created_new_type = true
      if type_vars = node.type_vars
        type = GenericClassType.new @program, scope, name, nil, type_vars, false
        type.splat_index = node.splat_index
        if extern
          node.raise "can only use Extern attribute with non-generic structs"
        end
      else
        type = NonGenericClassType.new @program, scope, name, nil, false
        type.extern = extern
        type.extern_union = extern_union
        type.packed = packed
      end
      type.abstract = node.abstract?
      type.struct = node.struct?
    end

    type.private = true if node.visibility.private?

    node_superclass = node.superclass
    if node_superclass
      if type_vars = node.type_vars
        free_vars = {} of String => TypeVar
        type_vars.each do |type_var|
          free_vars[type_var] = type.as(GenericType).type_parameter(type_var)
        end
      else
        free_vars = nil
      end

      # find_root_generic_type_parameters is false because
      # we don't want to find T in this case:
      #
      # class A(T)
      #   class B < T
      #   end
      # end
      #
      # We search for a superclass starting from the current
      # type, A(T) in this case, but we don't want to find
      # type parameters because they will always be unbound.
      superclass = lookup_type(node_superclass,
        free_vars: free_vars,
        find_root_generic_type_parameters: false)
      case superclass
      when GenericClassType
        node_superclass.raise "wrong number of type vars for #{superclass} (given 0, expected #{superclass.type_vars.size})"
      when NonGenericClassType, GenericClassInstanceType
        if superclass == @program.enum
          node_superclass.raise "can't inherit Enum. Use the enum keyword to define enums"
        end
      else
        node_superclass.raise "#{superclass} is not a class, it's a #{superclass.type_desc}"
      end
    else
      superclass = node.struct? ? program.struct : program.reference
    end

    if node.superclass && !created_new_type && type.superclass != superclass
      node.raise "superclass mismatch for class #{type} (#{superclass} for #{type.superclass})"
    end

    if created_new_type && superclass
      if node.struct? != superclass.struct?
        node.raise "can't make #{node.struct? ? "struct" : "class"} '#{node.name}' inherit #{superclass.type_desc} '#{superclass.to_s}'"
      end

      if superclass.struct? && !superclass.abstract?
        node.raise "can't extend non-abstract struct #{superclass}"
      end
    end

    if created_new_type
      type.superclass = superclass

      # If it's SomeClass(T) < Foo(T), or SomeClass < Foo(Int32),
      # we want to add SomeClass as a subclass of Foo(T)
      if superclass.is_a?(GenericClassInstanceType)
        superclass.generic_type.add_subclass(type)
      end
    end

    scope.types[name] = type
    node.resolved_type = type

    attach_doc type, node

    pushing_type(type) do
      run_hooks(hook_type(superclass), type, :inherited, node) if created_new_type
      node.body.accept self
    end

    if created_new_type
      type.force_add_subclass
    end

    false
  end

  def visit(node : ModuleDef)
    check_outside_exp node, "declare module"

    scope, name, type = lookup_type_def(node)

    if type
      type = type.remove_alias

      unless type.module?
        node.raise "#{type} is not a module, it's a #{type.type_desc}"
      end

      type = type.as(ModuleType)
    else
      if type_vars = node.type_vars
        type = GenericModuleType.new @program, scope, name, type_vars
        type.splat_index = node.splat_index
      else
        type = NonGenericModuleType.new @program, scope, name
      end
      scope.types[name] = type
    end

    type.private = true if node.visibility.private?

    node.resolved_type = type

    attach_doc type, node

    pushing_type(type) do
      node.body.accept self
    end

    false
  end

  def visit(node : Alias)
    check_outside_exp node, "declare alias"

    existing_type = current_type.types[node.name]?
    if existing_type
      if existing_type.is_a?(AliasType)
        node.raise "alias #{node.name} is already defined"
      else
        node.raise "can't alias #{node.name} because it's already defined as a #{existing_type.type_desc}"
      end
    end

    alias_type = AliasType.new(@program, current_type, node.name, node.value)
    attach_doc alias_type, node
    current_type.types[node.name] = alias_type

    alias_type.private = true if node.visibility.private?

    node.resolved_type = alias_type

    false
  end

  def visit(node : Macro)
    check_outside_exp node, "declare macro"

    node.set_type @program.nil

    if node.name == "finished"
      @finished_hooks << FinishedHook.new(current_type, node)
      return false
    end

    target = current_type.metaclass.as(ModuleType)
    begin
      target.add_macro node
    rescue ex : Crystal::Exception
      node.raise ex.message
    end

    false
  end

  def visit(node : Def)
    check_outside_exp node, "declare def"

    attributes = check_valid_attributes node, ValidDefAttributes, "def"
    node.doc ||= attributes_doc()
    check_ditto node

    is_instance_method = false

    target_type = case receiver = node.receiver
                  when Nil
                    is_instance_method = true
                    current_type
                  when Var
                    unless receiver.name == "self"
                      receiver.raise "def receiver can only be a Type or self"
                    end
                    current_type.metaclass
                  else
                    type = lookup_type(receiver)
                    metaclass = type.metaclass
                    case metaclass
                    when LibType
                      receiver.raise "can't define method in lib #{metaclass}"
                    when GenericClassInstanceMetaclassType
                      receiver.raise "can't define method in generic instance #{metaclass}"
                    when GenericModuleInstanceMetaclassType
                      receiver.raise "can't define method in generic instance #{metaclass}"
                    end
                    metaclass
                  end

    target_type = target_type.as(ModuleType)

    process_def_attributes node, attributes

    if node.abstract?
      if (target_type.class? || target_type.struct?) && !target_type.abstract?
        node.raise "can't define abstract def on non-abstract #{target_type.type_desc}"
      end
      if target_type.metaclass?
        node.raise "can't define abstract def on metaclass"
      end
    end

    primitive_attribute = attributes.try &.find { |attr| attr.name == "Primitive" }
    if primitive_attribute
      process_primitive_attribute(node, primitive_attribute)
    end

    if target_type.struct? && !target_type.metaclass? && node.name == "finalize"
      node.raise "structs can't have finalizers because they are not tracked by the GC"
    end

    target_type.add_def node
    node.set_type @program.nil

    if is_instance_method
      # If it's an initialize method, we define a `self.new` for
      # the type, initially empty. We will fill it once we know if
      # a type defines a `finalize` method, but defining it now
      # allows `previous_def` for a next `def self.new` definition
      # to find this method.
      if node.name == "initialize"
        new_method = node.expand_new_signature_from_initialize(target_type)
        target_type.metaclass.as(ModuleType).add_def(new_method)

        # And we register it to later complete it
        new_expansions << {original: node, expanded: new_method}
      end

      run_hooks target_type.metaclass, target_type, :method_added, node, Call.new(nil, "method_added", [node] of ASTNode).at(node.location)
    end

    false
  end

  private def process_primitive_attribute(node, attribute)
    if attribute.args.size != 1
      attribute.raise "expected Primitive attribute to have one argument"
    end

    arg = attribute.args.first
    unless arg.is_a?(SymbolLiteral)
      arg.raise "expected Primitive argument to be a symbol literal"
    end

    value = arg.value

    unless node.body.is_a?(Nop)
      node.raise "method marked as Primitive must have an empty body"
    end

    primitive = Primitive.new(value)
    primitive.location = node.location

    node.body = primitive
  end

  def visit(node : Include)
    check_outside_exp node, "include"
    include_in current_type, node, :included
    false
  end

  def visit(node : Extend)
    check_outside_exp node, "extend"
    include_in current_type.metaclass, node, :extended
    false
  end

  def visit(node : LibDef)
    check_outside_exp node, "declare lib"

    link_attributes, call_convention = process_lib_attributes

    scope = current_type_scope(node)

    type = scope.types[node.name]?
    if type
      node.raise "#{node.name} is not a lib" unless type.is_a?(LibType)
    else
      type = LibType.new @program, scope, node.name
      scope.types[node.name] = type
    end
    node.resolved_type = type

    type.private = true if node.visibility.private?
    type.add_link_attributes(link_attributes)
    type.call_convention = call_convention if call_convention

    pushing_type(type) do
      @in_lib = true
      node.body.accept self
      @in_lib = false
    end

    false
  end

  def visit(node : CStructOrUnionDef)
    unless node.union?
      attributes = check_valid_attributes node, ValidStructDefAttributes, "struct"
    end

    type = current_type.types[node.name]?
    if type
      unless type.is_a?(NonGenericClassType)
        node.raise "#{node.name} is already defined as #{type.type_desc}"
      end

      if !type.extern? || (type.extern_union? != node.union?)
        node.raise "#{node.name} is already defined as #{type.type_desc}"
      end

      node.raise "#{node.name} is already defined"
    else
      type = NonGenericClassType.new(@program, current_type, node.name, @program.struct)
      type.struct = true
      type.extern = true
      type.extern_union = node.union?
      current_type.types[node.name] = type
    end

    node.resolved_type = type

    type.packed = true if Attribute.any?(attributes, "Packed")

    false
  end

  def visit(node : TypeDef)
    type = current_type.types[node.name]?
    if type
      node.raise "#{node.name} is already defined"
    else
      typed_def_type = lookup_type(node.type_spec)
      typed_def_type = check_allowed_in_lib node.type_spec, typed_def_type
      current_type.types[node.name] = TypeDefType.new @program, current_type, node.name, typed_def_type
    end
  end

  def visit(node : EnumDef)
    check_outside_exp node, "declare enum"

    attributes = check_valid_attributes node, ValidEnumDefAttributes, "enum"
    attributes_doc = attributes_doc()

    scope, name, enum_type = lookup_type_def(node)

    if enum_type
      unless enum_type.is_a?(EnumType)
        node.raise "#{name} is not a enum, it's a #{enum_type.type_desc}"
      end
    end

    if base_type = node.base_type
      enum_base_type = lookup_type(base_type)
      unless enum_base_type.is_a?(IntegerType)
        base_type.raise "enum base type must be an integer type"
      end
    else
      enum_base_type = @program.int32
    end

    is_flags = Attribute.any?(attributes, "Flags")
    all_value = interpret_enum_value(NumberLiteral.new(0), enum_base_type)
    existed = !!enum_type
    enum_type ||= begin
      EnumType.new(@program, scope, name, enum_base_type, is_flags)
    end

    enum_type.private = true if node.visibility.private?

    node.resolved_type = enum_type
    attach_doc enum_type, node

    enum_type.doc ||= attributes_doc
    @attributes = nil

    pushing_type(enum_type) do
      counter = is_flags ? 1 : 0
      counter, all_value = visit_enum_members(node, node.members, counter, all_value,
        existed: existed,
        enum_type: enum_type,
        enum_base_type: enum_base_type,
        is_flags: is_flags)
    end

    if enum_type.types.empty?
      node.raise "enum #{node.name} must have at least one member"
    end

    unless existed
      if is_flags
        unless enum_type.types["None"]?
          none = NumberLiteral.new(0, enum_base_type.kind)
          none.type = enum_type
          enum_type.add_constant Arg.new("None", default_value: none)

          define_enum_none_question_method(enum_type, node)
        end

        unless enum_type.types["All"]?
          all = NumberLiteral.new(all_value, enum_base_type.kind)
          all.type = enum_type
          enum_type.add_constant Arg.new("All", default_value: all)
        end
      end

      scope.types[name] = enum_type
    end

    false
  end

  def visit_enum_members(node, members, counter, all_value, **options)
    members.each do |member|
      counter, all_value =
        visit_enum_member(node, member, counter, all_value, **options)
    end
    {counter, all_value}
  end

  def visit_enum_member(node, member, counter, all_value, **options)
    case member
    when MacroIf
      expanded = expand_inline_macro(member, mode: Program::MacroExpansionMode::Enum)
      visit_enum_member(node, expanded, counter, all_value, **options)
    when MacroExpression
      expanded = expand_inline_macro(member, mode: Program::MacroExpansionMode::Enum)
      visit_enum_member(node, expanded, counter, all_value, **options)
    when MacroFor
      expanded = expand_inline_macro(member, mode: Program::MacroExpansionMode::Enum)
      visit_enum_member(node, expanded, counter, all_value, **options)
    when Expressions
      visit_enum_members(node, member.expressions, counter, all_value, **options)
    when Arg
      existed = options[:existed]
      enum_type = options[:enum_type]
      base_type = options[:enum_base_type]
      is_flags = options[:is_flags]

      if options[:existed]
        node.raise "can't reopen enum and add more constants to it"
      end

      if is_flags && !@in_lib && {"None", "All"}.includes?(member.name)
        member.raise "flags enum can't contain None or All members, they are autogenerated"
      end

      if default_value = member.default_value
        counter = interpret_enum_value(default_value, base_type)
      end

      if default_value.is_a?(Crystal::NumberLiteral)
        enum_base_kind = base_type.kind
        if (enum_base_kind == :i32) && (enum_base_kind != default_value.kind)
          default_value.raise "enum value must be an Int32"
        end
      end

      all_value |= counter
      const_value = NumberLiteral.new(counter, base_type.kind)
      member.default_value = const_value
      if enum_type.types.has_key?(member.name)
        member.raise "enum '#{enum_type}' already contains a member named '#{member.name}'"
      end

      define_enum_question_method(enum_type, member, is_flags)

      const_member = enum_type.add_constant member
      const_member.doc = member.doc
      check_ditto const_member

      if member_location = member.location
        const_member.add_location(member_location)
      end

      const_value.type = enum_type
      counter = is_flags ? counter * 2 : counter + 1
      {counter, all_value}
    else
      member.accept self
      {counter, all_value}
    end
  end

  def define_enum_question_method(enum_type, member, is_flags)
    method_name = is_flags ? "includes?" : "=="
    body = Call.new(Var.new("self").at(member), method_name, Path.new(member.name).at(member)).at(member)
    a_def = Def.new("#{member.name.underscore}?", body: body).at(member)
    enum_type.add_def a_def
  end

  def define_enum_none_question_method(enum_type, node)
    body = Call.new(Call.new(nil, "value").at(node), "==", NumberLiteral.new(0)).at(node)
    a_def = Def.new("none?", body: body).at(node)
    enum_type.add_def a_def
  end

  def visit(node : Expressions)
    node.expressions.each_with_index do |child, i|
      begin
        child.accept self
      rescue SkipMacroException
        node.expressions.delete_at(i..-1)
        break
      end
    end
    false
  end

  def visit(node : Assign)
    type_assign(node.target, node.value, node)
    false
  end

  def type_assign(target : Var, value, node)
    @vars[target.name] = MetaVar.new(target.name)
    value.accept self
    false
  end

  def type_assign(target : Path, value, node)
    # We are inside the assign, so we go outside it to check if we are inside an outer expression
    @exp_nest -= 1
    check_outside_exp node, "declare constant"
    @exp_nest += 1

    scope = current_type_scope(target)

    type = scope.types[target.names.first]?
    if type
      target.raise "already initialized constant #{type}"
    end

    const = Const.new(@program, scope, target.names.first, value)
    const.private = true if target.visibility.private?
    attach_doc const, node

    scope.types[target.names.first] = const

    target.target_const = const
  end

  def type_assign(target, value, node)
    value.accept self

    # Prevent to assign instance variables inside nested expressions.
    # `@exp_nest > 1` is to check nested expressions. We cannot use `inside_exp?` simply
    # because `@exp_nest` is increased when `node` is `Assign`.
    if @exp_nest > 1 && target.is_a?(InstanceVar)
      node.raise "can't use instance variables at the top level"
    end

    false
  end

  def visit(node : VisibilityModifier)
    node.exp.visibility = node.modifier
    node.exp.accept self

    # Can only apply visibility modifier to def, type, macro or a macro call
    case exp = node.exp
    when ClassDef, ModuleDef, EnumDef, Alias, LibDef
      if node.modifier.private?
        return false
      else
        node.raise "can only use 'private' for types"
      end
    when Assign
      if (target = exp.target).is_a?(Path)
        if node.modifier.private?
          return false
        else
          node.raise "can only use 'private' for constants"
        end
      end
    when Def
      return false
    when Macro
      if node.modifier.private?
        return false
      else
        node.raise "can only use 'private' for macros"
      end
    when Call
      # Don't give an error yet: wait to see if the
      # call doesn't resolve to a method/macro
      return false
    end

    node.raise "can't apply visibility modifier"
  end

  def visit(node : ProcLiteral)
    old_vars_keys = @vars.keys

    node.def.args.each do |arg|
      @vars[arg.name] = MetaVar.new(arg.name)
    end

    node.def.body.accept self

    # Now remove these vars, but only if they weren't vars before
    node.def.args.each do |arg|
      @vars.delete(arg.name) unless old_vars_keys.includes?(arg.name)
    end

    false
  end

  def visit(node : FunDef)
    check_outside_exp node, "declare fun"

    if node.body && !current_type.is_a?(Program)
      node.raise "can only declare fun at lib or global scope"
    end

    call_convention = check_call_convention_attributes node
    attributes = check_valid_attributes node, ValidFunDefAttributes, "fun"
    node.doc ||= attributes_doc()
    check_ditto node

    # Copy call convention from lib, if any
    scope = current_type
    if !call_convention && scope.is_a?(LibType)
      call_convention = scope.call_convention
    end

    # We fill the arguments and return type in TypeDeclarationVisitor
    external = External.new(node.name, ([] of Arg), node.body, node.real_name).at(node)
    external.doc = node.doc
    external.call_convention = call_convention
    external.varargs = node.varargs?
    external.fun_def = node
    process_def_attributes external, attributes
    node.external = external

    false
  end

  def visit(node : TypeDeclaration)
    if (var = node.var).is_a?(Var)
      @vars[var.name] = MetaVar.new(var.name)
    end
    false
  end

  def visit(node : UninitializedVar)
    if (var = node.var).is_a?(Var)
      @vars[var.name] = MetaVar.new(var.name)
    end
    false
  end

  def visit(node : MultiAssign)
    node.targets.each do |target|
      if target.is_a?(Var)
        @vars[target.name] = MetaVar.new(target.name)
      end
      target.accept self
    end

    node.values.each &.accept self
    false
  end

  def visit(node : Rescue)
    if name = node.name
      @vars[name] = MetaVar.new(name)
    end

    node.body.accept self

    false
  end

  def visit(node : Call)
    node.scope = node.global? ? @program : current_type.metaclass
    !expand_macro(node, raise_on_missing_const: false, first_pass: true)
  end

  def visit(node : Out)
    exp = node.exp
    if exp.is_a?(Var)
      @vars[exp.name] = MetaVar.new(exp.name)
    end
    true
  end

  def visit(node : Block)
    old_vars_keys = @vars.keys

    # When accepting a block, declare variables for block arguments.
    # These are needed for macro expansions to parser identifiers
    # as variables and not calls.
    node.args.each do |arg|
      @vars[arg.name] = MetaVar.new(arg.name)
    end

    node.body.accept self

    # Now remove these vars, but only if they weren't vars before
    node.args.each do |arg|
      @vars.delete(arg.name) unless old_vars_keys.includes?(arg.name)
    end

    false
  end

  def process_lib_attributes
    attributes = @attributes
    return {nil, nil} unless attributes

    @attributes = nil
    link_attributes = [] of LinkAttribute
    call_convention = nil
    attributes.each do |attr|
      case attr.name
      when "Link"
        link_attributes << LinkAttribute.from(attr)
      when "CallConvention"
        call_convention = parse_call_convention(attr, call_convention)
      else
        attr.raise "illegal attribute for lib, valid attributes are: Link, CallConvention"
      end
    end
    {link_attributes, call_convention}
  end

  def include_in(current_type, node, kind)
    node_name = node.name

    type = lookup_type(node_name, lazy_self: true)
    case type
    when GenericModuleType
      node.raise "wrong number of type vars for #{type} (given 0, expected #{type.type_vars.size})"
    when .module?
      # OK
    else
      node_name.raise "#{type} is not a module, it's a #{type.type_desc}"
    end

    begin
      current_type.as(ModuleType).include type
      run_hooks hook_type(type), current_type, kind, node
    rescue ex : TypeException
      node.raise "at '#{kind}' hook", ex
    end
  end

  def run_hooks(type_with_hooks, current_type, kind, node, call = nil)
    type_with_hooks.as?(ModuleType).try &.hooks.try &.each do |hook|
      next if hook.kind != kind

      expansion = expand_macro(hook.macro, node) do
        if call
          @program.expand_macro hook.macro, call, current_type.instance_type
        else
          @program.expand_macro hook.macro.body, current_type.instance_type
        end
      end

      node.add_hook_expansion(expansion)
    end

    if kind == :inherited && (superclass = type_with_hooks.instance_type.superclass)
      run_hooks(superclass.metaclass, current_type, kind, node)
    end
  end

  private def hook_type(type)
    type = type.generic_type if type.is_a?(GenericInstanceType)
    type.metaclass
  end

  def check_call_convention_attributes(node)
    attributes = @attributes
    return unless attributes

    call_convention = nil

    attributes.reject! do |attr|
      next false unless attr.name == "CallConvention"

      call_convention = parse_call_convention(attr, call_convention)
      true
    end

    call_convention
  end

  def parse_call_convention(attr, call_convention)
    if call_convention
      attr.raise "call convention already specified"
    end

    if attr.args.size != 1
      attr.wrong_number_of_arguments "attribute CallConvention", attr.args.size, 1
    end

    call_convention_node = attr.args.first
    unless call_convention_node.is_a?(StringLiteral)
      call_convention_node.raise "argument to CallConvention must be a string"
    end

    value = call_convention_node.value
    call_convention = LLVM::CallConvention.parse?(value)
    unless call_convention
      call_convention_node.raise "invalid call convention. Valid values are #{LLVM::CallConvention.values.join ", "}"
    end
    call_convention
  end

  def attach_doc(type, node)
    if @program.wants_doc?
      type.doc ||= node.doc
    end

    if node_location = node.location
      type.add_location(node_location)
    end
  end

  def check_ditto(node)
    stripped_doc = node.doc.try &.strip
    if stripped_doc == ":ditto:" || stripped_doc == "ditto"
      node.doc = @last_doc
    end

    @last_doc = node.doc
  end

  def attributes_doc
    @attributes.try(&.first?).try &.doc
  end

  def process_def_attributes(node, attributes)
    attributes.try &.each do |attribute|
      case attribute.name
      when "NoInline"     then node.no_inline = true
      when "AlwaysInline" then node.always_inline = true
      when "Naked"        then node.naked = true
      when "ReturnsTwice" then node.returns_twice = true
      when "Raises"       then node.raises = true
      end
    end
  end

  private def process_class_def_struct_attributes
    extern = false
    extern_union = false
    packed = false

    @attributes.try &.each do |attr|
      case attr.name
      when "Extern"
        unless attr.args.empty?
          attr.raise "Extern attribute can't have positional arguments, only named arguments: 'union'"
        end

        attr.named_args.try &.each do |named_arg|
          case named_arg.name
          when "union"
            value = named_arg.value
            if value.is_a?(BoolLiteral)
              extern_union = value.value
            else
              value.raise "Extern 'union' attribute must be a boolean, not #{value.class_desc}"
            end
          else
            named_arg.raise "unknown Extern named argument, valid arguments are: 'union'"
          end
        end

        extern = true
      when "Packed"
        packed = true
      else
        attr.raise "illegal attribute for struct declaration, valid attributes are: Packed, Extern"
      end
    end

    @attributes = nil

    {extern, extern_union, packed}
  end

  def lookup_type_def(node : ASTNode)
    scope, name = lookup_type_def_name(node)
    type = scope.types[name]?
    if type && node.doc
      type.doc = node.doc
    end
    {scope, name, type}
  end

  def lookup_type_def_name(node : ASTNode)
    scope, name = lookup_type_def_name(node.name)
    if current_type.is_a?(Program)
      scope = program.check_private(node) || scope
    end
    {scope, name}
  end

  def lookup_type_def_name(path : Path)
    if path.names.size == 1 && !path.global?
      scope = current_type
      name = path.names.first
    else
      path = path.clone
      name = path.names.pop
      scope = lookup_type_def_name_creating_modules path
    end

    if scope.is_a?(EnumType)
      path.raise "can't declare type inside enum #{scope}"
    end

    {scope.as(ModuleType), name}
  end

  def lookup_type_def_name_creating_modules(path : Path)
    base_type = path.global? ? program : current_type
    target_type = base_type.lookup_path(path).as?(Type).try &.remove_alias_if_simple

    unless target_type
      next_type = base_type
      path.names.each do |name|
        next_type = base_type.lookup_path_item(name, lookup_in_namespace: false, include_private: true, location: path.location)
        if next_type
          if next_type.is_a?(ASTNode)
            path.raise "execpted #{name} to be a type"
          end
        else
          if base_type.is_a?(EnumType)
            path.raise "can't declare type inside enum #{base_type}"
          end

          next_type = NonGenericModuleType.new(@program, base_type.as(ModuleType), name)
          if (location = path.location)
            next_type.add_location(location)
          end
          base_type.types[name] = next_type
        end
        base_type = next_type
      end
      target_type = next_type
    end

    target_type.as(NamedType)
  end

  def current_type_scope(node)
    scope = current_type
    if scope.is_a?(Program) && node.visibility.private?
      scope = program.check_private(node) || scope
    end
    scope
  end

  # Turn all finished macros into expanded nodes, and
  # add them to the program
  def process_finished_hooks
    @finished_hooks.each do |hook|
      self.current_type = hook.scope
      expansion = expand_macro(hook.macro, hook.macro) do
        @program.expand_macro hook.macro.body, hook.scope
      end
      program.add_finished_hook(hook.scope, hook.macro, expansion)
    end
  end
end
