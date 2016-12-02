require "./semantic_visitor"

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
class Crystal::InstanceVarsInitializerVisitor < Crystal::SemanticVisitor
  def visit_any(node)
    case node
    when Assign
      node.target.is_a?(InstanceVar)
    when TypeDeclaration
      node.var.is_a?(InstanceVar)
    when FileNode, Expressions, ClassDef, ModuleDef, Alias, Include, Extend, LibDef, Def, Macro, Call, Require,
         MacroExpression, MacroIf, MacroFor, VisibilityModifier
      true
    else
      false
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

      unless current_type.lookup_instance_var?(target.name)
        ivar_visitor.undefined_instance_variable(current_type, target)
      end

      current_type.add_instance_var_initializer(target.name, value, current_type.is_a?(GenericType) ? nil : meta_vars)
      node.type = @program.nil
      return
    end
  end
end
