require "./repl"

# Gathers known local variables during a pry session.
# For example, if we have code like this:
#
# ```
# a = 1
#
# foo do |x|
#   b = 2
#   debugger
#
#   c = 3
# end
#
# d = 4
# ```
#
# When semantic analysis runs for the entire code, there will
# be local variables for a, b, c, d and x. However, at the
# point of `debugger` only a, b and x have a real, usable value
# (c and d will still be in the stack memory, but have garbage
# values.)
#
# This class is responsible for figuring out which local variables
# can be accessed when a `debugger` call is issued: essentially,
# any variable that is assigned or created before the `debugger` call.
class Crystal::Repl::LocalVarsGatherer < Crystal::Visitor
  @block : Block?

  # The meta vars that can be accessed at the location given
  # in the `initialize` method.
  getter meta_vars : MetaVars

  def initialize(@location : Location, @def : Def)
    @meta_vars = MetaVars.new
  end

  def gather : Nil
    self_var = @def.vars.try &.["self"]?
    @meta_vars["self"] = self_var.clone if self_var

    @def.args.each do |arg|
      var = @def.vars.try &.[arg.name]?
      @meta_vars[var.name] = var.clone if var
    end

    if @def.uses_block_arg? && (block_arg = @def.block_arg)
      block_arg_var = @def.vars.try &.[block_arg.name]?
      @meta_vars[block_arg.name] = block_arg_var.clone if block_arg_var
    end

    @def.body.accept self
  end

  def visit(node : Rescue)
    location = node.location
    if location && location.line_number >= @location.line_number
      return false
    end

    if name = node.name
      add_var(name)
    end

    true
  end

  def visit(node : Var)
    location = node.location
    if location && location.line_number >= @location.line_number
      return false
    end

    add_var(node.name)

    false
  end

  def visit(node : Block)
    location = node.location
    end_location = node.end_location

    if location && end_location && !(location.line_number < @location.line_number < end_location.line_number)
      return false
    end

    old_block = @block
    @block = node

    node.args.each &.accept self
    node.body.accept self

    @block = old_block

    false
  end

  def visit(node : ASTNode)
    true
  end

  private def add_var(name : String)
    var =
      if block = @block
        block.vars.try &.[name]?
      else
        @def.vars.try &.[name]?
      end

    @meta_vars[var.name] = var.clone if var
  end
end
