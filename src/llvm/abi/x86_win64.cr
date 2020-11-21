require "../abi"

# Based on https://github.com/rust-lang/rust/blob/29ac04402d53d358a1f6200bea45a301ff05b2d1/src/librustc_trans/trans/cabi_x86_win64.rs
class LLVM::ABI::X86_Win64 < LLVM::ABI::X86
  private def compute_arg_types(atys, context)
    atys.map do |t|
      case t.kind
      when Type::Kind::Struct
        size = target_data.abi_size(t)
        case size
        when 1 then ArgType.direct(t, context.int8)
        when 2 then ArgType.direct(t, context.int16)
        when 4 then ArgType.direct(t, context.int32)
        when 8 then ArgType.direct(t, context.int64)
        else        ArgType.indirect(t, nil)
        end
      else
        non_struct(t, context)
      end
    end
  end
end
