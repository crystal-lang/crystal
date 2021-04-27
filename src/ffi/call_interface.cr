module FFI
  struct CallInterface
    def initialize(@cif : LibFFI::Cif)
    end

    def call(fn : Void*, values : Pointer(Void*))
      rc = 0_u64

      LibFFI.call(
        pointerof(@cif),
        fn,
        pointerof(rc),
        values,
      )
    end
  end
end
