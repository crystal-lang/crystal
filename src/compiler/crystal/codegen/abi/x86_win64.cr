require "./x86"

# Based on https://github.com/rust-lang/rust/blob/29ac04402d53d358a1f6200bea45a301ff05b2d1/src/librustc_trans/trans/cabi_x86_win64.rs
class Crystal::ABI::X86_Win64 < Crystal::ABI::X86
  private def compute_arg_types(atys, context)
    atys.map do |t|
      case t.kind
      when LLVM::Type::Kind::Struct
        size = target_data.abi_size(t)
        case size
        when 1 then ArgType.direct(t, context.int8)
        when 2 then ArgType.direct(t, context.int16)
        when 4 then ArgType.direct(t, context.int32)
        when 8 then ArgType.direct(t, context.int64)
        else        ArgType.indirect(t, LLVM::Attribute::ByVal)
        end
      when LLVM::Type::Kind::Integer
        if t == context.int128
          ArgType.indirect(t, nil)
        else
          non_struct(t, context)
        end
      else
        non_struct(t, context)
      end
    end
  end

  private def compute_return_type(rty, ret_def, context)
    # Match GCC and Clang's behavior:
    # https://github.com/llvm/llvm-project/blob/c5f954af1066a98bc39f5f8f3f1be4cfd8cafd63/clang/lib/CodeGen/Targets/X86.cpp#L3674
    if ret_def && rty == context.int128
      ArgType.direct(rty, context.int64.vector(2))
    else
      super
    end
  end
end
