module FFI
  struct CallInterface
    def self.new(abi : FFI::ABI, args : Array(FFI::Type), return_type : FFI::Type) : CallInterface
      # TODO: is there a way to avoid this malloc?
      cif = Pointer(LibFFI::Cif).malloc(1)

      status = LibFFI.prep_cif(
        cif,
        abi,
        args.size,
        return_type,
        args.to_unsafe.as(Pointer(LibFFI::Type*)),
      )

      unless status.ok?
        raise "Error on LibFFI.prep_cif: #{status}"
      end

      new(cif)
    end

    def initialize(@cif : Pointer(LibFFI::Cif))
    end

    def call(fn : Void*, values : Array(Void*))
      rc = 0_u64

      LibFFI.call(
        @cif,
        fn,
        pointerof(rc),
        values,
      )
    end

    def to_unsafe
      @cif
    end
  end
end
