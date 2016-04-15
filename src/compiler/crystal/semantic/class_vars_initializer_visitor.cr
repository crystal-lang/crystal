require "./base_type_visitor"

module Crystal
  record ClassVarInitializer,
    owner : ClassVarContainer,
    name : String,
    node : ASTNode,
    meta_vars : MetaVars

  class Program
    def visit_class_vars_initializers(node)
      visitor = ClassVarsInitializerVisitor.new(self)
      node.accept visitor

      # First gather them all
      class_var_initializers = [] of ClassVarInitializer
      visitor.class_vars.each do |owner, vars|
        vars.each do |name, node|
          meta_vars = MetaVars.new
          class_var_initializers << ClassVarInitializer.new(owner, name, node, meta_vars)
        end
      end

      # Put the simple ones (literal like nil, 1, true, "foo", etc.) at the beginning,
      # so they are initialized before everything else and they are typed and can
      # be used by code that could come before them, so circular dependencies are less
      # of a problem.
      simple_vars, complex_vars = class_var_initializers.partition do |initializer|
        node = initializer.node
        case node
        when Nop, NilLiteral, BoolLiteral, NumberLiteral, CharLiteral,
             StringLiteral, SymbolLiteral
          true
        else
          false
        end
      end
      class_var_initializers = simple_vars + complex_vars

      # Now type them
      class_var_initializers.each do |initializer|
        owner = initializer.owner
        node = initializer.node
        name = initializer.name
        meta_vars = initializer.meta_vars

        main_visitor = MainVisitor.new(self, meta_vars: meta_vars)
        main_visitor.scope = owner.metaclass
        node.accept main_visitor

        owner.class_vars[name].bind_to(node)
      end

      @class_var_initializers = class_var_initializers

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

      @class_vars = {} of ClassVarContainer => Hash(String, ASTNode)
    end

    def visit_any(node)
      case node
      when Assign
        node.target.is_a?(ClassVar)
      when FileNode, Expressions, ClassDef, ModuleDef, EnumDef, Alias, Include, Extend, LibDef, Def, Macro, Call
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
      if node.global
        node.scope = @mod
      else
        node.scope = current_type.metaclass
      end

      if expand_macro(node, raise_on_missing_const: false)
        false
      else
        true
      end
    end

    def visit(node : Assign)
      target = node.target as ClassVar
      value = node.value

      # This is to check that the class var's type exists
      # (its type could be guessed, or it had an explicit type)
      lookup_class_var(target)

      owner = class_var_owner(target)
      cvars = @class_vars[owner] ||= {} of String => ASTNode
      cvars[target.name] = value

      false
    end

    def inside_block?
      false
    end
  end
end
