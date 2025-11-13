require "./ffi"

module Crystal::FFI
  struct Closure
    def initialize(call_interface : CallInterface, closure_fun : LibFFI::ClosureFun, user_data : Void*)
      @closure = LibFFI.closure_alloc(LibFFI::SIZEOF_CLOSURE, out @code)
      unless @closure
        raise "Error on LibFFI.closure_alloc"
      end

      status = LibFFI.prep_closure_loc(@closure, call_interface, closure_fun, user_data, @code)
      unless status.ok?
        raise "Error on LibFFI.prep_closure_loc: #{status}"
      end
    end

    def cast(t : T.class) forall T
      T.new(@code.as(Pointer(Void)), Pointer(Void).null)
    end

    def to_unsafe
      @code
    end
  end
end
