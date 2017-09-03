# Here we mix the result of explicit type declarations for
# global, class and instance variables with the implicit types
# guessed from assignments to them.
#
# If a type is explicit, the guess is not used (it might later
# give a compile error on incompatible types, on MainVisitor).
#
# If the type of an instance variable is implicit a bit more
# logic is involved since we need to check if a variable is
# assigned in all of the initialize methods, or if the initializers
# are defined in a superclass, if super is called, etc.
struct Crystal::TypeDeclarationProcessor
  record TypeDeclarationWithLocation,
    type : Type,
    location : Location,
    uninitialized : Bool

  # This captures an initialize info: it's related Def,
  # and which instance variables are assigned. Useful
  # to determine nilable instance variables.
  class InitializeInfo
    getter :def
    property instance_vars : Array(String)?

    def initialize(@def : Def)
    end
  end

  # Captures an error related to a type that can't be used
  # for an instance/class/global variable. The node is used
  # to give the error at its location.
  record Error,
    node : ASTNode,
    type : Type

  # The types we guess for instance types can be nodes or types.
  # In the case of a generic type we might have:
  #
  # ```
  # class Foo(T)
  #   def foo
  #     @x = T.new
  #   end
  #
  #   def foo
  #     @x = 1
  #   end
  # end
  # ```
  #
  # In the above case we know @x is of type T (but we don't know what
  # T is when instantiated) and Int32 (we know that type). So we
  # keep a list of all types and nodes, and we eventually resolve them
  # all when a generic type is instantiated.
  class InstanceVarTypeInfo
    property type : Type
    property outside_def
    getter location

    def initialize(@location : Location, @type : Type)
      @outside_def = false
    end
  end

  record NilableInstanceVar,
    info : InitializeInfo,
    name : String

  private getter type_decl_visitor
  private getter type_guess_visitor

  def initialize(@program : Program)
    # The type of instance variables. The last one wins.
    #
    # In the case of instance variables we can't always match a type
    # because they might be declared in generic types, for example:
    #
    # ```
    # class Foo(T)
    #   @x : T
    # end
    # ```
    #
    # In that case we remember that @x has a T node associated with it,
    # and only resolve it when instantiating the generic type.
    @explicit_instance_vars = {} of Type => Hash(String, TypeDeclarationWithLocation)

    # The types we guess for instance vars, when not explicit
    @guessed_instance_vars = {} of Type => Hash(String, InstanceVarTypeInfo)

    # Info related to a type's initialize methods
    @initialize_infos = {} of Type => Array(InitializeInfo)

    # Instance variables that are initialized outside a method (at the class level)
    @instance_vars_outside = {} of Type => Array(String)

    # Instance vars that are determined to be non-nilable because
    # they are initialized in at least one of the initialize methods.
    @non_nilable_instance_vars = {} of Type => Array(String)

    # Nilable variables there were detected to not be initilized in an initialize,
    # but a superclass does initialize it. It's only an error if the explicit/guessed
    # type is not nilable itself.
    @nilable_instance_vars = {} of Type => Hash(String, InitializeInfo)

    # Errors related to types like Class, Int and Reference used for
    # instance variables. These are gathered by the guesser, and later
    # removed if an explicit type is found (in remove_error).
    @errors = {} of Type => Hash(String, Error)

    # Types that have a single macro def initialize
    @has_macro_def = Set(Type).new

    @type_decl_visitor = TypeDeclarationVisitor.new(@program, @explicit_instance_vars)

    @type_guess_visitor = TypeGuessVisitor.new(@program, @explicit_instance_vars,
      @guessed_instance_vars, @initialize_infos, @instance_vars_outside, @errors)
  end

  def process(node)
    # First check type declarations
    @program.visit_with_finished_hooks(node, type_decl_visitor)

    # Use the last type found for class variables to declare them
    type_decl_visitor.class_vars.each do |owner, vars|
      vars.each do |name, type|
        declare_meta_type_var(owner.class_vars, owner, name, type)
      end
    end

    # Then use several syntactic rules to infer the types of
    # variables that don't have an explicit type set
    @program.visit_with_finished_hooks(node, type_guess_visitor)

    # Process class variables
    type_guess_visitor.class_vars.each do |owner, vars|
      vars.each do |name, info|
        # No need to freeze its type because it is frozen by check_class_var_errors
        declare_meta_type_var(owner.class_vars, owner, name, info, freeze_type: false)
      end
    end

    compute_non_nilable_instance_vars

    process_instance_vars_declarations

    # Check that instance vars that weren't initialized in an initialize,
    # but a superclass does initialize then, are nilable, and if not
    # give an error
    check_nilable_instance_vars

    check_cant_use_type_errors

    check_class_var_errors(type_decl_visitor.class_vars, type_guess_visitor.class_vars)

    {node, self}
  end

  private def declare_meta_type_var(vars, owner, name, type : Type, location : Location? = nil, instance_var = false, freeze_type = true)
    if instance_var && location && !owner.allows_instance_vars?
      raise_cant_declare_instance_var(owner, location)
    end

    remove_error owner, name

    if owner.extern? && !type.allowed_in_lib?
      raise TypeException.new("only primitive types, pointers, structs, unions, enums and tuples are allowed in extern struct declarations, not #{type}", location.not_nil!)
    end

    if owner.is_a?(NonGenericModuleType) || owner.is_a?(NonGenericClassType)
      type = type.replace_type_parameters(owner)
    end

    var = MetaTypeVar.new(name)
    var.owner = owner
    var.type = type
    var.bind_to(var)
    var.freeze_type = type if freeze_type
    var.location = location
    vars[name] = var
    var
  end

  private def declare_meta_type_var(vars, owner, name, info : TypeGuessVisitor::TypeInfo, freeze_type = true)
    type = info.type
    type = Type.merge!(type, @program.nil) unless info.outside_def
    declare_meta_type_var(vars, owner, name, type, freeze_type: freeze_type)
  end

  private def declare_meta_type_var(vars, owner, name, info : TypeDeclarationWithLocation, instance_var = false, check_nilable = true, freeze_type = true)
    if instance_var && !owner.allows_instance_vars?
      raise_cant_declare_instance_var(owner, info.location)
    end

    var = declare_meta_type_var(vars, owner, name, info.type.as(Type), info.location, freeze_type: freeze_type)
    var.location = info.location

    # Check if var is uninitialized
    var.uninitialized = true if info.uninitialized

    # If the variable is gueseed to be nilable because it is not initialized
    # in all of the initialize methods, and the explicit type is not nilable,
    # give an error right now
    if check_nilable && instance_var && !var.type.includes_type?(@program.nil)
      if nilable_instance_var?(owner, name)
        raise_not_initialized_in_all_initialize(var, name, owner)
      end
    end

    var
  end

  private def raise_cant_declare_instance_var(owner, location)
    raise TypeException.new("can't declare instance variables in #{owner}", location)
  end

  private def process_instance_vars_declarations
    owners = @explicit_instance_vars.keys + @guessed_instance_vars.keys
    owners.uniq!

    # We traverse types from the top of the hierarchy, processing
    # explicit vars first and then guessed ones. We must do this at the
    # same type to avoid declaring an explicit type in a subclass and
    # then find out the variable belongs to a superclass.
    owners = sort_types_by_depth(owners)
    owners.each do |owner|
      vars = @explicit_instance_vars[owner]?
      vars.try &.each do |name, type_decl|
        process_owner_instance_var_declaration(owner, name, type_decl)
      end

      vars = @guessed_instance_vars[owner]?
      vars.try &.each do |name, type_decl|
        process_owner_guessed_instance_var_declaration(owner, name, type_decl)
      end
    end
  end

  private def process_owner_instance_var_declaration(owner, name, type_decl)
    # Generic instances already have their instance vars
    # set from uninstantiated generic types
    return if owner.is_a?(GenericInstanceType)

    if owner.metaclass?
      raise TypeException.new("can't declare instance variables in #{owner}", type_decl.location)
    end

    # Check if a superclass already defined this variable
    supervar = owner.lookup_instance_var?(name)

    if supervar && supervar.owner != owner
      # Redeclaring a variable with the same type is OK
      unless supervar.type.same?(type_decl.type)
        raise TypeException.new("instance variable '#{name}' of #{supervar.owner}, with #{owner} < #{supervar.owner}, is already declared as #{supervar.type} (trying to re-declare as #{type_decl.type})", type_decl.location)
      end
    else
      declare_meta_type_var(owner.instance_vars, owner, name, type_decl, instance_var: true, check_nilable: !owner.module?)
      remove_error owner, name

      if owner.is_a?(GenericType)
        owner.generic_types.each_value do |generic_type|
          new_type = type_decl.type.replace_type_parameters(generic_type)
          new_type_decl = TypeDeclarationWithLocation.new(new_type, type_decl.location, type_decl.uninitialized)
          declare_meta_type_var(generic_type.instance_vars, generic_type, name, new_type_decl, instance_var: true, check_nilable: false)
        end
      end

      if owner.is_a?(NonGenericModuleType)
        # Transfer this declaration to including types, recursively
        owner.raw_including_types.try &.each do |including_type|
          process_owner_instance_var_declaration(including_type, name, type_decl)
        end
      end

      if owner.is_a?(GenericModuleType)
        # Transfer this declaration to including types, recursively
        owner.raw_including_types.try &.each do |including_type|
          process_owner_instance_var_declaration(including_type, name, type_decl)
        end
      end
    end
  end

  private def check_non_nilable_for_generic_module(owner, name, type_decl)
    case owner
    when GenericModuleType
      remove_error owner, name
      owner.inherited.try &.each do |inherited|
        check_non_nilable_for_generic_module(inherited, name, type_decl)
      end
    when NonGenericModuleType
      remove_error owner, name
      owner.raw_including_types.try &.each do |inherited|
        check_non_nilable_for_generic_module(inherited, name, type_decl)
      end
    when NonGenericClassType
      var = owner.lookup_instance_var(name).instance_var
      if !var.type.includes_type?(@program.nil)
        if nilable_instance_var?(owner, name)
          raise_not_initialized_in_all_initialize(var, name, owner)
        end
      end
    when GenericClassType
      if nilable_instance_var?(owner, name)
        if !has_syntax_nil?(type_decl.type)
          raise_not_initialized_in_all_initialize(type_decl.location, name, owner)
        end
      end
    end
  end

  private def has_syntax_nil?(node)
    case node
    when Union
      node.types.any? { |type| has_syntax_nil?(type) }
    when Path
      # TODO: we should actually check that this resolves to the top-level Nil type
      node.names.size == 1 && node.names.first == "Nil"
    else
      false
    end
  end

  private def process_owner_guessed_instance_var_declaration(owner, name, type_info)
    # Generic instances already have their instance vars
    # set from uninstantiated generic types
    return if owner.is_a?(GenericInstanceType)

    case owner
    when NonGenericClassType
      # If a superclass already defines this variable we ignore
      # the guessed type information for subclasses
      supervar = owner.lookup_instance_var?(name)
      return if supervar

      type = type_info.type
      if nilable_instance_var?(owner, name)
        type = Type.merge!(type, @program.nil)
      end

      # If the only type that we were able to infer was nil, it's the same
      # as not being able to infer anything (having a variable of just
      # Nil is not useful and is the same as not having it at all, at
      # least for non-generic types)
      if type.nil_type?
        raise_nil_instance_var owner, name, type_info.location
      end

      declare_meta_type_var(owner.instance_vars, owner, name, type, type_info.location, instance_var: true)
    when NonGenericModuleType
      type = type_info.type
      if nilable_instance_var?(owner, name)
        type = Type.merge!([type, @program.nil])
      end

      # Same as above, only Nil makes no sense
      if type.nil_type?
        return
      end

      declare_meta_type_var(owner.instance_vars, owner, name, type, type_info.location, instance_var: true)
      remove_error owner, name
      owner.raw_including_types.try &.each do |including_type|
        process_owner_guessed_instance_var_declaration(including_type, name, type_info)
        remove_error including_type, name
      end
    when GenericClassType
      type = type_info.type
      if nilable_instance_var?(owner, name)
        type = Type.merge!([type, @program.nil])
      end

      # Same as above, only Nil makes no sense
      if type.nil_type?
        raise_nil_instance_var owner, name, type_info.location
      end

      declare_meta_type_var(owner.instance_vars, owner, name, type, type_info.location, instance_var: true)

      owner.generic_types.each_value do |generic_type|
        new_type = type.replace_type_parameters(generic_type)
        declare_meta_type_var(generic_type.instance_vars, generic_type, name, new_type, type_info.location, instance_var: true)
      end

      remove_error owner, name
    when GenericModuleType
      type = type_info.type
      if nilable_instance_var?(owner, name)
        type = Type.merge!([type, @program.nil])
      end

      declare_meta_type_var(owner.instance_vars, owner, name, type, type_info.location, instance_var: true)
      remove_error owner, name
      owner.raw_including_types.try &.each do |including_type|
        process_owner_guessed_instance_var_declaration(including_type, name, type_info)
        remove_error including_type, name
      end
    end
  end

  private def nilable_instance_var?(owner, name)
    return false if @has_macro_def.includes?(owner)

    non_nilable_vars = @non_nilable_instance_vars[owner]?
    !non_nilable_vars || (non_nilable_vars && !non_nilable_vars.includes?(name))
  end

  private def raise_nil_instance_var(owner, name, location)
    raise TypeException.new("instance variable #{name} of #{owner} was inferred to be Nil, but Nil alone provides no information", location)
  end

  private def compute_non_nilable_instance_vars
    owners = sort_types_by_depth(@initialize_infos.keys).uniq!

    owners.each do |owner|
      # Compute nilable variables because of initialize
      infos = find_initialize_infos(owner)

      if infos
        @has_macro_def << owner if infos.size == 1 && infos.first.def.macro_def?
        non_nilable = compute_non_nilable_instance_vars_multi(owner, infos)
      end

      # We must also take into account those variables that are
      # initialized outside of an initializer
      non_nilable_outisde = compute_non_nilable_outside(owner)

      # And add them all into one array
      non_nilable = merge_non_nilable_vars(non_nilable, non_nilable_outisde)

      if non_nilable
        @non_nilable_instance_vars[owner] = non_nilable
      end
    end
  end

  private def merge_non_nilable_vars(v1, v2)
    if v1
      if v2
        v1 = (v1 + v2).uniq!
      end
    elsif v2
      v1 = v2
    end
    v1
  end

  private def compute_non_nilable_instance_vars_multi(owner, infos)
    # Get ancestor's non-nilable variables
    ancestor = owner.ancestors.first?
    ancestor = uninstantiate(ancestor)
    if ancestor
      ancestor_non_nilable = @non_nilable_instance_vars[ancestor]?
    end

    # If the ancestor has non-nilable instance vars, check that all initialize either call
    # super or assign all of those variables
    if ancestor_non_nilable
      infos.each do |info|
        unless info.def.calls_super? || info.def.calls_initialize? || info.def.macro_def?
          ancestor_non_nilable.each do |name|
            # If the variable is initialized outside, it's OK
            next if initialized_outside?(owner, name)

            unless info.try &.instance_vars.try &.includes?(name)
              # Rememebr that this variable wasn't initialized here, and later error
              # if it turns out to be non-nilable
              nilable_vars = @nilable_instance_vars[owner] ||= {} of String => InitializeInfo
              nilable_vars[name] = info
            end
          end
        end
      end
    end

    # Get all instance vars assigned in all the initialize methods
    all_instance_vars = [] of String
    infos.each do |info|
      info.instance_vars.try { |ivars| all_instance_vars.concat(ivars) }
    end
    all_instance_vars.uniq!

    # Then check which ones are assigned in all of them
    non_nilable = [] of String
    all_instance_vars.each do |instance_var|
      infos.each do |info|
        # If an initialize calls another initialize, consider it like it initializes
        # all instance vars, because the other initialize will have to do that
        next if info.def.calls_initialize?

        # Assume a macro def initializes all of them
        # (will be checked later)
        next if info.def.macro_def?

        # Similarly, calling previous_def would have the vars initialized
        # in the other def
        next if info.def.calls_previous_def?

        # It's non-nilable if it's initialized outside
        next if initialized_outside?(owner, instance_var)

        # If an initialize with an ivar calls super and an ancestor has already
        # typed the instance var as non-nilable
        next if info.def.calls_super? && ancestor_non_nilable.try(&.includes?(instance_var))

        unless info.try(&.instance_vars.try(&.includes?(instance_var)))
          all_assigned = false
          # Rememebr that this variable wasn't initialized here, and later error
          # if it turns out to be non-nilable
          nilable_vars = @nilable_instance_vars[owner] ||= {} of String => InitializeInfo
          nilable_vars[instance_var] = info
          break
        end
      end
      non_nilable << instance_var
    end

    merge_non_nilable_vars(non_nilable, ancestor_non_nilable)
  end

  private def initialized_outside?(owner, name)
    if @instance_vars_outside[owner]?.try &.includes?(name)
      return true
    end

    owner.ancestors.any? do |ancestor|
      @instance_vars_outside[ancestor]?.try &.includes?(name)
    end
  end

  private def compute_non_nilable_outside(owner)
    non_nilable_outisde = nil
    non_nilable_outisde = compute_non_nilable_outside_single(owner, non_nilable_outisde)
    owner.ancestors.each do |ancestor|
      ancestor = uninstantiate(ancestor)
      non_nilable_outisde = compute_non_nilable_outside_single(ancestor, non_nilable_outisde)
    end
    non_nilable_outisde
  end

  private def compute_non_nilable_outside_single(owner, non_nilable_outisde)
    if vars = @instance_vars_outside[owner]?
      non_nilable_outisde ||= [] of String
      vars.each do |name|
        non_nilable_outisde << name unless non_nilable_outisde.includes?(name)
      end
    end
    non_nilable_outisde
  end

  private def find_initialize_infos(owner)
    # Find the first type in the ancestor chain, including self,
    # that defines an initialize method
    infos = @initialize_infos[owner]?
    return infos if infos && !infos.empty?

    owner.ancestors.each do |ancestor|
      ancestor = uninstantiate(ancestor)
      infos = @initialize_infos[ancestor]?
      return infos if infos && !infos.empty?
    end

    nil
  end

  private def check_nilable_instance_vars
    @nilable_instance_vars.each do |owner, vars|
      vars.each do |name, info|
        ivar = owner.lookup_instance_var?(name)
        if ivar
          if ivar.type.includes_type?(@program.nil)
            # If the variable is nilable because it was not initialized
            # in all of the initialize methods, and it's not explicitly nil,
            # give an error and ask to be explicit.
            if nilable_instance_var?(owner, name)
              raise_doesnt_explicitly_initializes(info, name, ivar)
            end
          elsif owner == ivar.owner
            raise_doesnt_explicitly_initializes(info, name, ivar)
          else
            info.def.raise "this 'initialize' doesn't initialize instance variable '#{name}' of #{ivar.owner}, with #{owner} < #{ivar.owner}, rendering it nilable"
          end
        else
          info.def.raise "this 'initialize' doesn't initialize instance variable '#{name}', rendering it nilable"
        end
      end
    end
  end

  def check_non_nilable_class_vars_without_initializers
    type_decl_visitor.class_vars.each do |owner, vars|
      vars.each_key do |name|
        check_non_nilable_class_var_without_initializers(owner, name)
      end
    end

    type_guess_visitor.class_vars.each do |owner, vars|
      vars.each_key do |name|
        check_non_nilable_class_var_without_initializers(owner, name)
      end
    end
  end

  private def check_non_nilable_class_var_without_initializers(owner, name)
    class_var = owner.class_vars[name]?
    return unless class_var

    return if class_var.uninitialized?

    var_type = class_var.type?
    return unless var_type

    if !class_var.initializer && !var_type.includes_type?(@program.nil_type)
      class_var.raise "class variable '#{name}' of #{owner} is not nilable (it's #{var_type}) so it must have an initializer"
    end
  end

  private def remove_error(type, name)
    @errors[type]?.try &.delete(name)
  end

  private def check_cant_use_type_errors
    @errors.each do |type, entries|
      entries.each do |name, error|
        case name
        when .starts_with?("$")
          error.node.raise "can't use #{error.type} as the type of global variable #{name}, use a more specific type"
        when .starts_with?("@@")
          error.node.raise "can't use #{error.type} as the type of class variable #{name} of #{type}, use a more specific type"
        when .starts_with?("@")
          error.node.raise "can't use #{error.type} as the type of instance variable #{name} of #{type}, use a more specific type"
        end
      end
    end
  end

  private def check_class_var_errors(type_decl_class_vars, guesser_class_vars)
    {type_decl_class_vars, guesser_class_vars}.each do |all_vars|
      all_vars.each do |owner, vars|
        vars.each do |name, info|
          owner_class_var = owner.lookup_class_var?(name)
          next unless owner_class_var

          owner.ancestors.each do |ancestor|
            next unless ancestor.is_a?(ClassVarContainer)

            ancestor_class_var = ancestor.lookup_class_var?(name)
            next unless ancestor_class_var

            if owner_class_var.type.implements?(ancestor_class_var.type)
              owner_class_var.type = ancestor_class_var.type
            end

            if owner_class_var.type != ancestor_class_var.type
              raise TypeException.new("class variable '#{name}' of #{owner} is already defined as #{ancestor_class_var.type} in #{ancestor}", info.location)
            end
          end

          owner_class_var.freeze_type = owner_class_var.type
        end
      end
    end
  end

  private def raise_not_initialized_in_all_initialize(node : ASTNode, name, owner)
    node.raise "instance variable '#{name}' of #{owner} was not initialized directly in all of the 'initialize' methods, rendering it nilable. Indirect initialization is not supported."
  end

  private def raise_not_initialized_in_all_initialize(location : Location, name, owner)
    raise TypeException.new "instance variable '#{name}' of #{owner} was not initialized directly in all of the 'initialize' methods, rendering it nilable. Indirect initialization is not supported.", location
  end

  private def raise_doesnt_explicitly_initializes(info, name, ivar)
    info.def.raise <<-MSG
      this 'initialize' doesn't explicitly initialize instance variable '#{name}' of #{ivar.owner}, rendering it nilable

      The instance variable '#{name}' is initialized in other 'initialize' methods,
      and by not initializing it here it's not clear if the variable is supposed
      to be nilable or if this is a mistake.

      To fix this error, either assign nil to it here:

        #{name} = nil

      Or declare it as nilable outside at the type level:

        #{name} : (#{ivar.type})?
      MSG
  end

  private def sort_types_by_depth(types)
    # We sort types. We put modules first, because if these declare types
    # of instance variables we want them declared in including types.
    # Then we sort other types by depth, so we declare types first in
    # superclass and then in subclasses. Finally, two modules or classes
    # with the same depths are sorted by name.
    types.sort_by! do |t|
      {t.module? ? 0 : 1, t.depth, t.to_s}
    end
  end

  private def uninstantiate(type)
    if type.is_a?(GenericInstanceType)
      type.generic_type
    else
      type
    end
  end
end
