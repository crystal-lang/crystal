{% skip_file if flag?(:without_interpreter) %}
require "./repl"

class Crystal::Repl::EscapingException < Exception
  getter exception_pointer : UInt8*

  def initialize(@interpreter : Interpreter, @exception_pointer : UInt8*)
  end

  def to_s(io : IO)
    type_id = @exception_pointer.as(Int32*).value
    type = @interpreter.context.type_from_id(type_id)

    decl = UninitializedVar.new(Var.new("ex"), TypeNode.new(@interpreter.context.program.exception.virtual_type))
    call = Call.new(Var.new("ex"), "inspect_with_backtrace")
    exps = Expressions.new([decl, call] of ASTNode)

    begin
      value = Interpreter.interpret(context, exps) do |stack|
        stack.as(UInt8**).value = @exception_pointer
      end
      if value.type == context.program.string
        value.pointer.as(UInt8**).value.unsafe_as(String).to_s(io)
      else
        io.puts "Exception#inspect_with_backtrace didn't return a String :/"
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
