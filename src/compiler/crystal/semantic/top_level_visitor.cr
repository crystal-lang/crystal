require "./base_type_visitor"

module Crystal
  class Program
    def visit_top_level(node)
      node.accept TopLevelVisitor.new(self)
      node
    end
  end

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
  class TopLevelVisitor < BaseTypeVisitor
    @inside_block : Int32

    def initialize(mod)
      super(mod)

      @inside_block = 0
      @process_types = 0
    end

    def processing_types
      @process_types += 1
      value = yield
      @process_types -= 1
      value
    end

    def visit(node : Path)
      @process_types > 0 ? super : false
    end

    def visit(node : Generic)
      @process_types > 0 ? super : false
    end

    def visit(node : ProcNotation)
      @process_types > 0 ? super : false
    end

    def visit(node : Union)
      @process_types > 0 ? super : false
    end

    def visit(node : Metaclass)
      @process_types > 0 ? super : false
    end

    def visit(node : Self)
      @process_types > 0 ? super : false
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
      return if @lib_def_pass == 2

      # We are inside the assign, so we go outside it to check if we are inside an outer expression
      @exp_nest -= 1
      check_outside_block_or_exp node, "declare constant"
      @exp_nest += 1

      type = current_type.types[target.names.first]?
      if type
        target.raise "already initialized constant #{type}"
      end

      target.bind_to value

      const = Const.new(@program, current_type, target.names.first, value, @scope)
      attach_doc const, node

      current_type.types[target.names.first] = const

      node.type = @program.nil
      target.target_const = const
    end

    def type_assign(target, value, node)
      value.accept self
      false
    end

    def visit(node : ClassDef)
      check_outside_block_or_exp node, "declare class"

      node_superclass = node.superclass

      if node_superclass
        superclass = lookup_path_type(node_superclass)
      else
        superclass = node.struct? ? program.struct : program.reference
      end

      if node_superclass.is_a?(Generic)
        unless superclass.is_a?(GenericClassType)
          node_superclass.raise "#{superclass} is not a generic class, it's a #{superclass.type_desc}"
        end

        if node_superclass.type_vars.size != superclass.type_vars.size
          node_superclass.wrong_number_of "type vars", superclass, node_superclass.type_vars.size, superclass.type_vars.size
        end
      end

      scope, name = process_type_name(node.name)

      type = scope.types[name]?

      if !type && superclass
        if node.struct? != superclass.struct?
          node.raise "can't make #{node.struct? ? "struct" : "class"} '#{node.name}' inherit #{superclass.type_desc} '#{superclass.to_s}'"
        end

        if superclass.struct? && !superclass.abstract?
          node.raise "can't extend non-abstract struct #{superclass}"
        end
      end

      created_new_type = false

      if type
        type = type.remove_alias

        unless type.is_a?(ClassType)
          node.raise "#{name} is not a #{node.struct? ? "struct" : "class"}, it's a #{type.type_desc}"
        end

        if node.struct? != type.struct?
          node.raise "#{name} is not a #{node.struct? ? "struct" : "class"}, it's a #{type.type_desc}"
        end

        if node.superclass && type.superclass != superclass
          node.raise "superclass mismatch for class #{type} (#{superclass} for #{type.superclass})"
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
      else
        case superclass
        when NonGenericClassType
          # OK
        when GenericClassType
          if node_superclass.is_a?(Generic)
            mapping = Hash.zip(superclass.type_vars, node_superclass.type_vars)
            superclass = InheritedGenericClass.new(@program, superclass, mapping)
          else
            node_superclass.not_nil!.wrong_number_of "type vars", superclass, 0, superclass.type_vars.size
          end
        else
          node_superclass.not_nil!.raise "#{superclass} is not a class, it's a #{superclass.type_desc}"
        end

        created_new_type = true
        if type_vars = node.type_vars
          type = GenericClassType.new @program, scope, name, superclass, type_vars, false
          type.splat_index = node.splat_index
        else
          type = NonGenericClassType.new @program, scope, name, superclass, false
        end
        type.abstract = node.abstract?
        type.struct = node.struct?

        if superclass.is_a?(InheritedGenericClass)
          superclass.extending_class = type
          superclass.extended_class.as(GenericClassType).add_inherited(type)
        end

        scope.types[name] = type
      end

      node.resolved_type = type

      attach_doc type, node

      pushing_type(type) do
        if created_new_type
          run_hooks(superclass.metaclass, type, :inherited, node)
        end

        node.body.accept self
      end

      if created_new_type
        raise "Bug" unless type.is_a?(InheritableClass)
        type.force_add_subclass
      end

      node.type = @program.nil

      false
    end

    def visit(node : ModuleDef)
      check_outside_block_or_exp node, "declare module"

      scope, name = process_type_name(node.name)

      type = scope.types[name]?
      if type
        type = type.remove_alias

        unless type.module?
          node.raise "#{type} is not a module, it's a #{type.type_desc}"
        end
      else
        if type_vars = node.type_vars
          type = GenericModuleType.new @program, scope, name, type_vars
          type.splat_index = node.splat_index
        else
          type = NonGenericModuleType.new @program, scope, name
        end
        scope.types[name] = type
      end

      node.resolved_type = type

      attach_doc type, node

      pushing_type(type) do
        node.body.accept self
      end

      node.type = @program.nil

      false
    end

    def visit(node : Alias)
      return false if @lib_def_pass == 2

      check_outside_block_or_exp node, "declare alias"

      check_no_typeof node.value

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

      node.type = @program.nil

      false
    end

    private def check_no_typeof(node)
      visitor = HasTypeofVisitor.new
      node.accept visitor
      if t = visitor.typeof
        t.raise "can't use typeof inside alias declaration"
      end
    end

    class HasTypeofVisitor < Visitor
      getter typeof : TypeOf?

      def initialize
        @typeof = nil
      end

      def visit(node : TypeOf)
        @typeof ||= node
        false
      end

      def visit(node : ASTNode)
        true
      end
    end

    def visit(node : Macro)
      check_outside_block_or_exp node, "declare macro"

      begin
        current_type.metaclass.add_macro node
      rescue ex : Crystal::Exception
        node.raise ex.message
      end

      node.set_type @program.nil
      false
    end

    def visit(node : Def)
      check_outside_block_or_exp node, "declare def"

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
                      type = lookup_path_type(receiver).metaclass
                      node.raise "can't define 'def' for lib" if type.is_a?(LibType)
                      type
                    end

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
          target_type.metaclass.add_def(new_method)

          # And we register it to later complete it
          @program.new_expansions << Program::NewExpansion.new(node, new_method)
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

      node.body = Primitive.new(value)
    end

    def visit(node : Include)
      check_outside_block_or_exp node, "include"

      include_in current_type, node, :included

      node.type = @program.nil

      false
    end

    def visit(node : Extend)
      check_outside_block_or_exp node, "extend"

      include_in current_type.metaclass, node, :extended

      node.type = @program.nil

      false
    end

    def visit(node : LibDef)
      check_outside_block_or_exp node, "declare lib"

      link_attributes = process_link_attributes

      type = current_type.types[node.name]?
      if type
        node.raise "#{node.name} is not a lib" unless type.is_a?(LibType)
      else
        type = LibType.new @program, current_type, node.name
        current_type.types[node.name] = type
      end
      node.resolved_type = type

      type.add_link_attributes(link_attributes)

      pushing_type(type) do
        @lib_def_pass = 1
        node.body.accept self
        @lib_def_pass = 2
        node.body.accept self
        @lib_def_pass = 0
      end

      node.type = @program.nil

      false
    end

    def visit(node : CStructOrUnionDef)
      if @lib_def_pass == 1 && !node.union?
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

        unless type.instance_vars.empty?
          node.raise "#{node.name} is already defined"
        end
      else
        type = NonGenericClassType.new(@program, current_type, node.name, @program.struct)
        type.struct = true
        type.extern = true
        type.extern_union = node.union?
        current_type.types[node.name] = type
      end

      if @lib_def_pass == 2
        pushing_type(type) do
          node.body.accept StructOrUnionVisitor.new(self, type)
        end
      end

      node.type = type

      if @lib_def_pass == 1 && !type.extern_union? && Attribute.any?(attributes, "Packed")
        type.packed = true
      end

      false
    end

    def visit(node : TypeDef)
      return if @lib_def_pass == 2

      type = current_type.types[node.name]?
      if type
        node.raise "#{node.name} is already defined"
      else
        processing_types do
          node.type_spec.accept self
        end

        typed_def_type = check_primitive_like node.type_spec
        current_type.types[node.name] = TypeDefType.new @program, current_type, node.name, typed_def_type
      end
    end

    def visit(node : EnumDef)
      return false if @lib_def_pass == 2

      check_outside_block_or_exp node, "declare enum"

      attributes = check_valid_attributes node, ValidEnumDefAttributes, "enum"
      attributes_doc = attributes_doc()

      scope, name = process_type_name(node.name)

      enum_type = scope.types[name]?
      if enum_type
        unless enum_type.is_a?(EnumType)
          node.raise "#{name} is not a enum, it's a #{enum_type.type_desc}"
        end
      end

      if base_type = node.base_type
        processing_types do
          base_type.accept self
        end
        enum_base_type = base_type.type.instance_type
        unless enum_base_type.is_a?(IntegerType)
          base_type.raise "enum base type must be an integer type"
        end
      else
        enum_base_type = @program.int32
      end

      is_flags = Attribute.any?(attributes, "Flags")
      all_value = interpret_enum_value(NumberLiteral.new(0), enum_base_type)
      existed = !!enum_type
      enum_type ||= EnumType.new(@program, scope, name, enum_base_type, is_flags)

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

      unless existed
        if is_flags
          unless enum_type.types["None"]?
            none = NumberLiteral.new(0, enum_base_type.kind)
            none.type = enum_type
            enum_type.add_constant Arg.new("None", default_value: none)
          end

          unless enum_type.types["All"]?
            all = NumberLiteral.new(all_value, enum_base_type.kind)
            all.type = enum_type
            enum_type.add_constant Arg.new("All", default_value: all)
          end
        end

        scope.types[name] = enum_type
        node.created_new_type = true
      end

      node.type = program.nil

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
        expanded = expand_inline_macro(member, mode: MacroExpansionMode::Enum)
        visit_enum_member(node, expanded, counter, all_value, **options)
      when MacroExpression
        expanded = expand_inline_macro(member, mode: MacroExpansionMode::Enum)
        visit_enum_member(node, expanded, counter, all_value, **options)
      when MacroFor
        expanded = expand_inline_macro(member, mode: MacroExpansionMode::Enum)
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
          const_member.locations << member_location
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
      a_def = Def.new("#{member.name.underscore}?", body: Call.new(Var.new("self").at(member), method_name, Path.new(member.name).at(member))).at(member)
      enum_type.add_def a_def
    end

    def visit(node : ExternalVar)
      return unless @lib_def_pass == 2

      attributes = check_valid_attributes node, ValidExternalVarAttributes, "external var"

      processing_types do
        node.type_spec.accept self
      end

      var_type = check_primitive_like node.type_spec
      thread_local = Attribute.any?(attributes, "ThreadLocal")

      type = current_type.as(LibType)
      type.add_var node.name, var_type, (node.real_name || node.name), thread_local

      false
    end

    def visit(node : VisibilityModifier)
      node.exp.visibility = node.modifier
      node.exp.accept self
      node.type = @program.nil

      # Can only apply visibility modifier to def, macro or a macro call
      case exp = node.exp
      when Def
        return false
      when Macro
        if current_type != @program.program
          node.raise "#{node.modifier.to_s.downcase} macros can only be declared at the top-level"
        end

        return false
      when Call
        # Don't give an error yet: wait to see if the
        # call doesn't resolve to a method/macro
        return false
      end

      node.raise "can't apply visibility modifier"
    end

    def visit(node : ProcLiteral)
      node.def.body.accept self
      false
    end

    def visit(node : FunDef)
      return false if @lib_def_pass == 1

      # Only declare the function, but do not type it
      # (we do that later in MainVisitor)
      body = node.body
      node.body = nil
      visit_fun_def(node)
      node.body = body

      false
    end

    def visit(node : Cast)
      node.obj.accept self
      false
    end

    def visit(node : NilableCast)
      node.obj.accept self
      false
    end

    def visit(node : IsA)
      node.obj.accept self
      false
    end

    def visit(node : TypeDeclaration)
      false
    end

    def visit(node : UninitializedVar)
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

      if expand_macro(node, raise_on_missing_const: false, first_pass: true)
        false
      else
        true
      end
    end

    def visit(node : Out)
      exp = node.exp
      if exp.is_a?(Var)
        @vars[exp.name] = MetaVar.new(exp.name)
      end
      true
    end

    def visit(node : Block)
      @inside_block += 1

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

      @inside_block -= 1

      false
    end

    def inside_block?
      @inside_block > 0
    end

    def process_link_attributes
      attributes = @attributes
      return unless attributes

      link_attributes = attributes.map do |attr|
        link_attribute_from_node(attr)
      end
      @attributes = nil
      link_attributes
    end

    def link_attribute_from_node(attr)
      name = attr.name
      args = attr.args
      named_args = attr.named_args

      if name != "Link"
        attr.raise "illegal attribute for lib, valid attributes are: Link"
      end

      if args.empty? && !named_args
        attr.raise "missing link arguments: must at least specify a library name"
      end

      lib_name = nil
      lib_ldflags = nil
      lib_static = false
      lib_framework = nil
      count = 0

      args.each do |arg|
        case count
        when 0
          unless arg.is_a?(StringLiteral)
            arg.raise "'lib' link argument must be a String"
          end
          lib_name = arg.value
        when 1
          unless arg.is_a?(StringLiteral)
            arg.raise "'ldflags' link argument must be a String"
          end
          lib_ldflags = arg.value
        when 2
          unless arg.is_a?(BoolLiteral)
            arg.raise "'static' link argument must be a Bool"
          end
          lib_static = arg.value
        when 3
          unless arg.is_a?(StringLiteral)
            arg.raise "'framework' link argument must be a String"
          end
          lib_framework = arg.value
        else
          attr.wrong_number_of "link arguments", args.size, "1..4"
        end

        count += 1
      end

      named_args.try &.each do |named_arg|
        value = named_arg.value

        case named_arg.name
        when "lib"
          if count > 0
            named_arg.raise "'lib' link argument already specified"
          end
          unless value.is_a?(StringLiteral)
            named_arg.raise "'lib' link argument must be a String"
          end
          lib_name = value.value
        when "ldflags"
          if count > 1
            named_arg.raise "'ldflags' link argument already specified"
          end
          unless value.is_a?(StringLiteral)
            named_arg.raise "'ldflags' link argument must be a String"
          end
          lib_ldflags = value.value
        when "static"
          if count > 2
            named_arg.raise "'static' link argument already specified"
          end
          unless value.is_a?(BoolLiteral)
            named_arg.raise "'static' link argument must be a Bool"
          end
          lib_static = value.value
        when "framework"
          if count > 3
            named_arg.raise "'framework' link argument already specified"
          end
          unless value.is_a?(StringLiteral)
            named_arg.raise "'framework' link argument must be a String"
          end
          lib_framework = value.value
        else
          named_arg.raise "unknown link argument: '#{named_arg.name}' (valid arguments are 'lib', 'ldflags', 'static' and 'framework')"
        end
      end

      LinkAttribute.new(lib_name, lib_ldflags, lib_static, lib_framework)
    end

    def include_in(current_type, node, kind)
      node_name = node.name
      type = lookup_path_type(node_name)

      unless type.module?
        node_name.raise "#{type} is not a module, it's a #{type.type_desc}"
      end

      if node_name.is_a?(Generic)
        unless type.is_a?(GenericModuleType)
          node_name.raise "#{type} is not a generic module"
        end

        if !type.splat_index && type.type_vars.size != node_name.type_vars.size
          node_name.wrong_number_of "type vars", type, node_name.type_vars.size, type.type_vars.size
        end

        node_name_type_vars = node_name.type_vars

        if splat_index = type.splat_index
          new_type_vars = Array(ASTNode).new(node_name_type_vars.size)
          type_var_index = 0
          type.type_vars.each_index do |index|
            if index == splat_index
              tuple_elements = [] of ASTNode
              (node_name_type_vars.size - (type.type_vars.size - 1)).times do
                tuple_elements << node_name_type_vars[type_var_index]
                type_var_index += 1
              end
              new_type_vars << TupleLiteral.new(tuple_elements)
            else
              new_type_vars << node_name_type_vars[type_var_index]
              type_var_index += 1
            end
          end
          node_name_type_vars = new_type_vars
        end

        mapping = Hash.zip(type.type_vars, node_name_type_vars)
        module_to_include = IncludedGenericModule.new(@program, type, current_type, mapping)

        type.add_inherited(current_type)
      else
        if type.is_a?(GenericModuleType)
          node_name.raise "#{type} is a generic module"
        else
          module_to_include = type
        end
      end

      begin
        current_type.as(ModuleType).include module_to_include
        run_hooks type.metaclass, current_type, kind, node
      rescue ex : TypeException
        node.raise "at '#{kind}' hook", ex
      end
    end

    class StructOrUnionVisitor < Visitor
      def initialize(@top_level_visitor : TopLevelVisitor, @struct_or_union : NonGenericClassType)
      end

      def visit(field : Arg)
        @top_level_visitor.processing_types do
          field.accept @top_level_visitor
        end

        restriction = field.restriction.not_nil!
        field_type = @top_level_visitor.check_primitive_like restriction
        if field_type.remove_typedef.void?
          restriction.raise "can't use Void as a #{@struct_or_union.type_desc} field type"
        end

        var_name = '@' + field.name

        if @struct_or_union.lookup_instance_var?(var_name)
          field.raise "#{@struct_or_union.type_desc} #{@struct_or_union} already defines a field named '#{field.name}'"
        end
        ivar = MetaTypeVar.new(var_name, field_type)
        ivar.owner = @struct_or_union
        add_field @struct_or_union, field.name, ivar
      end

      def visit(node : Include)
        @top_level_visitor.processing_types do
          node.name.accept @top_level_visitor
        end

        type = node.name.type.instance_type
        unless type.is_a?(NonGenericClassType) && type.extern? && !type.extern_union?
          node.name.raise "can only include C struct, not #{type.type_desc}"
        end

        type.instance_vars.each_value do |var|
          field_name = var.name[1..-1]
          if @struct_or_union.lookup_instance_var?(var.name)
            node.raise "struct #{type} has a field named '#{field_name}', which #{@struct_or_union} already defines"
          end
          add_field @struct_or_union, field_name, var
        end

        false
      end

      def visit(node : MacroIf | MacroFor | MacroExpression)
        expanded = @top_level_visitor.expand_inline_macro(node, mode: MacroExpansionMode::StructOrUnion)
        expanded.accept self
        false
      end

      def visit(node : ASTNode)
        true
      end

      def add_field(type, field_name, var)
        type.instance_vars[var.name] = var
        type.add_def Def.new("#{field_name}=", [Arg.new("value")], Primitive.new(type.extern_union? ? :union_set : :struct_set))
        type.add_def Def.new(field_name, body: InstanceVar.new(var.name))
      end
    end
  end
end
