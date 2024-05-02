require "../abi"

class LLVM::ABI::AVR < LLVM::ABI
  AVRTINY = StaticArray[
    "attiny4",
    "attiny5",
    "attiny9",
    "attiny10",
    "attiny102",
    "attiny104",
    "attiny20",
    "attiny40",
  ]

  def initialize(target_machine : TargetMachine, mcpu : String? = nil)
    super target_machine

    # "Reduced Tiny" core devices only have 16 General Purpose Registers
    if mcpu.in?(AVRTINY)
      @rsize = 4 # values above 4 bytes are returned by memory
      @rmin = 20 # 6 registers for call arguments (R25..R20)
    else
      @rsize = 8 # values above 8 bytes are returned by memory
      @rmin = 8  # 18 registers for call arguments (R25..R8)
    end
  end

  def align(type : Type) : Int32
    target_data.abi_alignment(type).to_i32
  end

  def size(type : Type) : Int32
    target_data.abi_size(type).to_i32
  end

  # Follows AVR GCC, while Clang (and Rust) are incompatible, despite LLVM
  # itself being compliant.
  #
  # - <https://gcc.gnu.org/wiki/avr-gcc>
  # - <https://bugs.llvm.org/show_bug.cgi?id=46140>
  def abi_info(atys : Array(Type), rty : Type, ret_def : Bool, context : Context) : LLVM::ABI::FunctionType
    ret_ty = compute_return_type(rty, ret_def, context)
    arg_tys = compute_arg_types(atys, context)
    FunctionType.new(arg_tys, ret_ty)
  end

  # Pass in registers unless the returned type is a struct larger than 8 bytes
  # (4 bytes on reduced tiny cores).
  #
  # Rust & Clang always return a struct _indirectly_.
  private def compute_return_type(rty, ret_def, context)
    if !ret_def
      ArgType.direct(context.void)
    elsif size(rty) > @rsize
      ArgType.indirect(rty, LLVM::Attribute::StructRet)
    else
      # let the LLVM AVR backend handle the pw2ceil padding of structs
      ArgType.direct(rty)
    end
  end

  # Fill the R25 -> R8 registers (R20 on reduced tiny cores), rounding odd byte
  # sizes to the next even number, then pass by memory (indirect), so {i8, i32}
  # are passed as R24 then R20..R23 (LSB -> MSB) for example.
  #
  # Rust & Clang always pass structs _indirectly_.
  private def compute_arg_types(atys, context)
    rn = 26
    atys.map do |aty|
      bytes = size(aty)
      bytes += 1 if bytes.odd?
      rn -= bytes

      if bytes == 0 || rn < @rmin
        ArgType.indirect(aty, LLVM::Attribute::StructRet)
      else
        # let the LLVM AVR backend handle the odd to next even number padding
        ArgType.direct(aty)
      end
    end
  end
end
