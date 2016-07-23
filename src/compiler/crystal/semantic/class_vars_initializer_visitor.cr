require "./base_type_visitor"

module Crystal
  class ClassVarInitializer
    getter owner : ClassVarContainer,
      name : String,
      meta_vars : MetaVars
    property node : ASTNode

    def initialize(@owner, @name, @node, @meta_vars)
    end
  end

  class Program
    def visit_class_vars_initializers(node)
      visitor = ClassVarsInitializerVisitor.new(self)
      node.accept visitor

      # First gather them all
      class_var_initializers = [] of ClassVarInitializer
      visitor.class_vars.each do |owner, vars|
        vars.each do |name, assign_and_node|
          node = assign_and_node[1]

          # If the initializer is nil there's no need to initialize anything
          next if node.is_a?(NilLiteral)

          meta_vars = MetaVars.new
          class_var_initializers << ClassVarInitializer.new(owner, name, node, meta_vars)
        end
      end

      # Put the simple ones (literal like nil, 1, true, "foo", etc.) at the beginning,
      # so they are initialized before everything else and they are typed and can
      # be used by code that could come before them, so circular dependencies are less
      # of a problem.
      simple_vars, complex_vars = class_var_initializers.partition &.node.simple_literal?
      class_var_initializers = simple_vars + complex_vars

      # Next assign their initializer, so we know which are initialized
      # and shouldn't raise an error when trying to accessing them
      # before they are defined
      class_var_initializers.each do |initializer|
        class_var = initializer.owner.class_vars[initializer.name]?
        class_var.initializer = initializer if class_var
      end

      # Now type them
      class_var_initializers.each do |initializer|
        owner = initializer.owner
        node = initializer.node
        name = initializer.name
        meta_vars = initializer.meta_vars

        main_visitor = MainVisitor.new(self, meta_vars: meta_vars)
        main_visitor.scope = owner.metaclass

        # We want to first type the value, because it might
        # happened that we couldn't guess a type from an expression
        # but that expression has an error: we want to signal
        # that error first.
        had_class_var = true
        class_var = owner.class_vars[name]?
        unless class_var
          class_var = MetaTypeVar.new(name)
          class_var.owner = owner
          had_class_var = false
        end

        node.accept main_visitor

        unless had_class_var
          main_visitor.undefined_class_variable(class_var, owner)
        end

        class_var.bind_to(node)
        class_var.initializer = initializer
        self.class_var_and_const_initializers << initializer
      end

      node
    end
  end

  # In this pass we gather class var initializers like:
  #
  # ```
  # class Foo
  #   @@x = 1
  # end
  # ```
  #
  # The last initializer set for a type is the one that
  # will be used.
  #
  # These initializers will be run as soon as the program
  # starts. This means that using such value before
  # reaching that line is possible (hoisting), and some
  # circular dependencies issues are also solved by this.
  # It also means that class variables don't have access to
  # outside local variables. This won't compile:
  #
  # ```
  # class Foo
  #   a = 1
  #   @@x = a # ERROR
  # end
  class ClassVarsInitializerVisitor < BaseTypeVisitor
    getter class_vars

    def initialize(mod)
      super(mod)

      @class_vars = {} of ClassVarContainer => Hash(String, {ASTNode, ASTNode})
    end

    def visit_any(node)
      case node
      when Assign
        node.target.is_a?(ClassVar)
      when TypeDeclaration
        node.var.is_a?(ClassVar)
      when FileNode, Expressions, ClassDef, ModuleDef, EnumDef, Alias, Include, Extend, LibDef, Def, Macro, Call, Require
        true
      else
        false
      end
    end

    def visit(node : ClassDef)
      check_outside_block_or_exp node, "declare class"

      pushing_type(node.resolved_type) do
        node.runtime_initializers.try &.each &.accept self
        node.body.accept self
      end

      false
    end

    def visit(node : ModuleDef)
      check_outside_block_or_exp node, "declare module"

      pushing_type(node.resolved_type) do
        node.body.accept self
      end

      false
    end

    def visit(node : EnumDef)
      check_outside_block_or_exp node, "declare enum"

      pushing_type(node.resolved_type) do
        node.members.each &.accept self
      end

      false
    end

    def visit(node : Alias)
      check_outside_block_or_exp node, "declare alias"

      false
    end

    def visit(node : Include)
      check_outside_block_or_exp node, "include"

      node.runtime_initializers.try &.each &.accept self

      false
    end

    def visit(node : Extend)
      check_outside_block_or_exp node, "extend"

      node.runtime_initializers.try &.each &.accept self

      false
    end

    def visit(node : LibDef)
      check_outside_block_or_exp node, "declare lib"

      false
    end

    def visit(node : Def)
      check_outside_block_or_exp node, "declare def"

      node.runtime_initializers.try &.each &.accept self

      false
    end

    def visit(node : Macro)
      check_outside_block_or_exp node, "declare macro"

      false
    end

    def visit(node : Call)
      node.scope = node.global? ? @program : current_type.metaclass

      if expand_macro(node, raise_on_missing_const: false)
        false
      else
        true
      end
    end

    def visit(node : Assign)
      target = node.target.as(ClassVar)
      value = node.value
      type_class_var(target, node, value)
      false
    end

    def visit(node : TypeDeclaration)
      target = node.var.as(ClassVar)
      value = node.value
      type_class_var(target, node, value) if value
      false
    end

    def type_class_var(target, node, value)
      owner = class_var_owner(target)
      cvars = @class_vars[owner] ||= {} of String => {ASTNode, ASTNode}
      existing = cvars[target.name]?
      cvars[target.name] = {node.as(ASTNode), value}
      if existing
        node_to_discard = existing[0]
        case node_to_discard
        when Assign
          node_to_discard.discarded = true
        when TypeDeclaration
          node_to_discard.discarded = true
        end
      end
    end

    def inside_block?
      false
    end
  end
end
