require "./repl"

class Crystal::Repl::EscapingException < Exception
  getter exception_pointer : Void*

  def initialize(@interpreter : Interpreter, @exception_pointer : Void*)
  end

  def to_s(io : IO)
    type_id = @exception_pointer.as(Int32*).value
    type = @interpreter.context.type_from_id(type_id)

    decl = UninitializedVar.new(Var.new("ex"), TypeNode.new(@interpreter.context.program.exception.virtual_type))
    call = Call.new(Var.new("ex"), "inspect_with_backtrace", Path.new("STDOUT"))
    exps = Expressions.new([decl, call] of ASTNode)

    begin
      Interpreter.interpret(context, exps) do |stack|
        stack.as(Void**).value = @exception_pointer
      end
    rescue ex
      io.puts "Error while calling inspect_with_backtrace on exception: #{ex.message}"
      io.puts type
    end
  end

  private def context
    @interpreter.context
  end
end
