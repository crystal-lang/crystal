require "./repl"

# Instructions together with their mapping back to AST nodes.
class Crystal::Repl::CompiledInstructions
  # An exception handler is a region (from `start_index` to `end_index` inclusive)
  # that, if an exception is raised, will make the flow go to `jump_index`
  # if `exception_types` is `nil` (this is for an `ensure` clause)
  # or if the raised exception is one of `exception_types`.
  record ExceptionHandler, start_index : Int32, end_index : Int32, exception_types : Array(Type)?, jump_index : Int32

  # The actual bytecode.
  getter instructions : Array(UInt8) = [] of UInt8

  # The nodes to refer from the instructions (by index)
  getter nodes : Hash(Int32, ASTNode) = {} of Int32 => ASTNode

  getter exception_handlers : Array(ExceptionHandler)?

  def add_rescue(start_index : Int32, end_index : Int32, exception_types : Array(Type), jump_index : Int32)
    return if start_index == end_index

    exception_handlers = @exception_handlers ||= [] of ExceptionHandler
    exception_handlers << ExceptionHandler.new(start_index, end_index, exception_types, jump_index)
  end

  def add_ensure(start_index : Int32, end_index : Int32, jump_index : Int32)
    return if start_index == end_index

    exception_handlers = @exception_handlers ||= [] of ExceptionHandler
    exception_handlers << ExceptionHandler.new(start_index, end_index, nil, jump_index)
  end
end
