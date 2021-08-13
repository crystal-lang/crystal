require "./repl"

class Crystal::Repl::EscapingException < Exception
  getter exception_pointer : Void*

  def initialize(@interpreter : Interpreter, @exception_pointer : Void*)
  end

  def to_s(io : IO)
    type_id = @exception_pointer.as(Int32*).value
    type = @interpreter.context.type_from_id(type_id)

    decl = UninitializedVar.new(Var.new("ex"), TypeNode.new(@interpreter.context.program.exception.virtual_type))
    call = Call.new(Var.new("ex"), "inspect_with_backtrace")
    exps = Expressions.new([decl, call] of ASTNode)

    begin
      meta_vars = MetaVars.new

      interpreter = Interpreter.new(context)
      # TODO: make stack private? Does it matter?
      interpreter.stack.as(Void**).value = @exception_pointer

      main_visitor = MainVisitor.new(context.program, meta_vars: meta_vars)

      exps = context.program.normalize(exps)
      exps = context.program.semantic(exps, main_visitor: main_visitor)

      value = interpreter.interpret(exps, main_visitor.meta_vars)

      if value.type == context.program.string
        value.pointer.as(UInt8**).value.unsafe_as(String).to_s(io)
      else
        io.puts type
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
