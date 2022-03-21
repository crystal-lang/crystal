module Crystal::FFI
  # This type represents the signature of a function call made through LibFFI.
  #
  # Different functions sharing the same signature can share the same `CallInterface`
  # instance.
  # Variadic functions need separate `CallInterface` instances for every variadic
  # signature.
  struct CallInterface
    def self.new(return_type : FFI::Type, arg_types : Array(FFI::Type), *, abi : LibFFI::ABI = :default) : CallInterface
      # TODO: is there a way to avoid this malloc?
      cif = Pointer(LibFFI::Cif).malloc(1)

      status = LibFFI.prep_cif(
        cif,
        abi,
        arg_types.size,
        return_type,
        arg_types.map(&.to_unsafe),
      )

      unless status.ok?
        raise "Error on LibFFI.prep_cif: #{status}"
      end

      new(cif)
    end

    def self.variadic(return_type : FFI::Type, arg_types : Array(FFI::Type), fixed_args : Int32, *, abi : LibFFI::ABI = :default) : CallInterface
      unless 0 <= fixed_args <= arg_types.size
        raise "invalid value for fixed_args"
      end

      # TODO: is there a way to avoid this malloc?
      cif = Pointer(LibFFI::Cif).malloc(1)

      status = LibFFI.prep_cif_var(
        cif,
        abi,
        fixed_args,
        arg_types.size,
        return_type,
        arg_types.map(&.to_unsafe),
      )

      unless status.ok?
        raise "Error on LibFFI.prep_cif_var: #{status}"
      end

      new(cif)
    end

    def initialize(@cif : Pointer(LibFFI::Cif))
    end

    # Calls the function at *function_pointer* with this call interface and the
    # given *arguments*.
    # The return value is assigned to *return_value*.
    def call(function_pointer : Void*, arguments : Pointer(Void*), return_value : Void*)
      LibFFI.call(
        @cif,
        function_pointer,
        return_value,
        arguments,
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
