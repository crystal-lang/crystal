require "./base_type_visitor"

module Crystal
  class Program
    def visit_instance_vars_initializers(node)
      node.accept InstanceVarsInitializerVisitor.new(self)
      node
    end
  end

  # In this pass we check instance var initializers like:
  #
  #     @x = 1
  #     @x : Int32 = 1
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
  class InstanceVarsInitializerVisitor < BaseTypeVisitor
    def visit_any(node)
      case node
      when Assign
        node.target.is_a?(InstanceVar)
      when TypeDeclaration
        node.var.is_a?(InstanceVar)
      when FileNode, Expressions, ClassDef, ModuleDef, Alias, Include, Extend, LibDef, Def, Macro, Call, Require
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
      node.scope = node.global? ? @program : current_type.metaclass

      if expand_macro(node, raise_on_missing_const: false)
        false
      else
        true
      end
    end

    def visit(node : Assign)
      target = node.target.as(InstanceVar)
      value = node.value
      type_instance_var(node, target, value)
      false
    end

    def visit(node : TypeDeclaration)
      target = node.var.as(InstanceVar)
      value = node.value
      type_instance_var(node, target, value) if value
      false
    end

    def type_instance_var(node, target, value)
      current_type = current_type()
      case current_type
      when Program, FileModule
        node.raise "can't use instance variables at the top level"
      when ClassType, NonGenericModuleType, GenericModuleType
        meta_vars = MetaVars.new
        ivar_visitor = MainVisitor.new(program, meta_vars: meta_vars)
        ivar_visitor.scope = current_type

        unless current_type.is_a?(GenericType)
          value.accept ivar_visitor
        end

        case current_type
        when NonGenericModuleType
          unless current_type.known_instance_vars.includes?(target.name)
            ivar_visitor.undefined_instance_variable(current_type, target)
          end
        when GenericModuleType
          unless current_type.known_instance_vars.includes?(target.name)
            ivar_visitor.undefined_instance_variable(current_type, target)
          end
        when GenericClassType
          unless current_type.known_instance_vars.includes?(target.name)
            ivar_visitor.undefined_instance_variable(current_type, target)
          end
        else
          ivar = current_type.lookup_instance_var?(target.name)
          unless ivar
            ivar_visitor.undefined_instance_variable(current_type, target)
          end
        end

        current_type.add_instance_var_initializer(target.name, value, meta_vars)
        node.type = @program.nil
        return
      end
    end

    def inside_block?
      false
    end
  end
end
