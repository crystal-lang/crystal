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
  record Initializer, scope : Type, target : InstanceVar, value : ASTNode, meta_vars : MetaVars
  getter initializers = [] of Initializer

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
      initializers << Initializer.new(current_type, target, value, MetaVars.new)
      node.type = @program.nil
      return
    else
      # TODO: can this happen?
    end
  end

  def finish
    scope_initializers = [] of InstanceVarInitializerContainer::InstanceVarInitializer?

    # First declare them, so when we type all of them we will have
    # the info of which instance vars have initializers (so they are not nil)
    initializers.each do |i|
      scope = i.scope
      unless scope.lookup_instance_var?(i.target.name)
        program.undefined_instance_variable(i.target, scope, nil)
      end

      scope_initializers <<
        scope.add_instance_var_initializer(i.target.name, i.value, scope.is_a?(GenericType) ? nil : i.meta_vars)
    end

    # Now type them
    initializers.each_with_index do |i, index|
      scope = i.scope
      value = i.value

      next if scope.is_a?(GenericType)

      # Check if we can autocast
      if value.supports_autocast?(!@program.has_flag?("no_number_autocast")) && (scope_initializer = scope_initializers[index])
        cloned_value = value.clone
        cloned_value.accept MainVisitor.new(program)
        if casted_value = MainVisitor.check_automatic_cast(@program, cloned_value, scope.lookup_instance_var(i.target.name).type)
          scope_initializer.value = casted_value
          next
        end
      end

      ivar_visitor = MainVisitor.new(program, meta_vars: i.meta_vars)
      ivar_visitor.scope = scope.metaclass
      value.accept ivar_visitor
    end
  end
end
