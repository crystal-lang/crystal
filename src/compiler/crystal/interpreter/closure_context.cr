class Crystal::Repl
  # Information about closured variables in a given context.
  class ClosureContext
    # The variables closures in the closest context
    getter vars : Hash(String, {Int32, Type})

    # The self type, if captured, otherwise nil.
    # Comes after vars, at the end of the closure (this closure never has a parent closure).
    getter self_type : Type?

    # The parent context, if any, where more closured variables might be reached
    getter parent : ClosureContext?

    # The total bytesize to hold all the immediate closure data.
    # If this context has a parent context, it will come at the end of this
    # data and occupy 8 bytes.
    getter bytesize : Int32

    def initialize(
      @vars : Hash(String, {Int32, Type}),
      @self_type : Type?,
      @parent : ClosureContext?,
      @bytesize : Int32
    )
    end
  end
end
