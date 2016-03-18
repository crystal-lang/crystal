require "./base_type_visitor"

module Crystal
  class Program
    def visit_initializers(node)
      node.accept InitializerVisitor.new(self)
      node
    end
  end

  # In this pass we check instance var initializers like:
  #
  #     @x = 1
  #
  # These initializers run when an instance is created,
  # so there's no way that the main code can use them before
  # creating an instance to use them. Conclusion: we must
  # analyze them before the main code.
  #
  # This solves the following problem:
  #
  # ```
  # # Here the compiler would complain because @bar
  # # wasn't initialized/analyzed yet
  # Foo.new.bar + 1
  #
  # class Foo
  #   @bar = 1
  #
  #   def bar
  #     @bar
  #   end
  # end
  # ```
  class InitializerVisitor < BaseTypeVisitor
    def initialize(mod)
      super(mod)
    end

    def visit_any(node)
      case node
      when Assign
        node.target.is_a?(InstanceVar)
      when FileNode, Expressions, ClassDef, ModuleDef, Alias, Include, Extend, LibDef, Def, Macro, Call
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
      target = node.target as InstanceVar
      value = node.value

      current_type = current_type()
      case current_type
      when Program, FileModule
        node.raise "can't use instance variables at the top level"
      when ClassType, NonGenericModuleType
        ivar_visitor = MainVisitor.new(mod)
        ivar_visitor.scope = current_type

        unless current_type.is_a?(GenericType)
          value.accept ivar_visitor
        end

        current_type.add_instance_var_initializer(target.name, value, ivar_visitor.meta_vars)
        node.type = @mod.nil
        return
      end
      false
    end

    def inside_block?
      false
    end
  end
end
