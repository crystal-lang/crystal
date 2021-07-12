module Crystal::FFI
  # :nodoc:
  struct CallInterface
    def self.new(abi : FFI::ABI, args : Array(FFI::Type), return_type : FFI::Type) : CallInterface
      # TODO: is there a way to avoid this malloc?
      cif = Pointer(LibFFI::Cif).malloc(1)

      status = LibFFI.prep_cif(
        cif,
        abi,
        args.size,
        return_type,
        args.map(&.to_unsafe),
      )

      unless status.ok?
        raise "Error on LibFFI.prep_cif: #{status}"
      end

      new(cif)
    end

    def self.variadic(abi : FFI::ABI, args : Array(FFI::Type), return_type : FFI::Type, fixed_args : Int32, total_args : Int32) : CallInterface
      # TODO: is there a way to avoid this malloc?
      cif = Pointer(LibFFI::Cif).malloc(1)

      status = LibFFI.prep_cif_var(
        cif,
        abi,
        fixed_args,
        total_args,
        return_type,
        args.map(&.to_unsafe),
      )

      unless status.ok?
        raise "Error on LibFFI.prep_cif_var: #{status}"
      end

      new(cif)
    end

    def initialize(@cif : Pointer(LibFFI::Cif))
    end

    def call(fn : Void*, values : Pointer(Void*), return_value : Void*)
      LibFFI.call(
        @cif,
        fn,
        return_value,
        values,
      )
    end

    def inspect(io : IO)
      io << "FFI::CallInterface("
      io << @cif.value
      io << ")"
    end

    def to_unsafe
      @cif
    end
  end
end
