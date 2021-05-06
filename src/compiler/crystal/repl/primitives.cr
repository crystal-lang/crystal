require "./compiler"

class Crystal::Repl::Compiler
  private def visit_primitive(node, body)
    case body.name
    when "unchecked_convert"
      obj = node.obj.not_nil!
      obj.accept self

      obj_type = obj.type
      target_type = body.type

      obj_kind = integer_or_float_kind(obj_type)
      target_kind = integer_or_float_kind(target_type)

      unless obj_kind && target_kind
        node.raise "BUG: missing handling of unchecked_convert for #{obj_type} (#{node.name})"
      end

      target_kind =
        case target_kind
        when :u8  then :i8
        when :u16 then :i16
        when :u32 then :i32
        when :u64 then :i64
        else           target_kind
        end

      case {obj_kind, target_kind}
      when {:i8, :i8}   then nop
      when {:i8, :i16}  then i8_to_i16
      when {:i8, :i32}  then i8_to_i32
      when {:i8, :i64}  then i8_to_i64
      when {:i8, :f32}  then i8_to_f32
      when {:i8, :f64}  then i8_to_f64
      when {:u8, :i8}   then nop
      when {:u8, :i16}  then u8_to_i16
      when {:u8, :i32}  then u8_to_i32
      when {:u8, :i64}  then u8_to_i64
      when {:u8, :f32}  then u8_to_f32
      when {:u8, :f64}  then u8_to_f64
      when {:i16, :i8}  then i16_to_i8_bang
      when {:i16, :i16} then nop
      when {:i16, :i32} then i16_to_i32
      when {:i16, :i64} then i16_to_i64
      when {:i16, :f32} then i16_to_f32
      when {:i16, :f64} then i16_to_f64
      when {:u16, :i8}  then i16_to_i8_bang
      when {:u16, :i16} then nop
      when {:u16, :i32} then u16_to_i32
      when {:u16, :i64} then u16_to_i64
      when {:u16, :f32} then u16_to_f32
      when {:u16, :f64} then u16_to_f64
      when {:i32, :i8}  then i32_to_i8_bang
      when {:i32, :i16} then i32_to_i16_bang
      when {:i32, :i32} then nop
      when {:i32, :i64} then i32_to_i64
      when {:i32, :f32} then i32_to_f32
      when {:i32, :f64} then i32_to_f64
      when {:u32, :i8}  then i32_to_i8_bang
      when {:u32, :i16} then i32_to_i16_bang
      when {:u32, :i32} then nop
      when {:u32, :u32} then nop
      when {:u32, :i64} then u32_to_i64
      when {:u32, :f32} then u32_to_f32
      when {:u32, :f64} then u32_to_f64
      when {:i64, :i8}  then i64_to_i8_bang
      when {:i64, :i16} then i64_to_i16_bang
      when {:i64, :i32} then i64_to_i32_bang
      when {:i64, :i64} then nop
      when {:i64, :f32} then i64_to_f32
      when {:i64, :f64} then i64_to_f64
      when {:u64, :i8}  then i64_to_i8_bang
      when {:u64, :i16} then i64_to_i16_bang
      when {:u64, :i32} then i64_to_i32_bang
      when {:u64, :i64} then nop
      when {:u64, :f32} then u64_to_f32
      when {:u64, :f64} then u64_to_f64
      when {:f32, :i8}  then f32_to_i8_bang
      when {:f32, :i16} then f32_to_i16_bang
      when {:f32, :i32} then f32_to_i32_bang
      when {:f32, :i64} then f32_to_i64_bang
      when {:f32, :f32} then nop
      when {:f32, :f64} then f32_to_f64
      when {:f64, :i8}  then f64_to_i8_bang
      when {:f64, :i16} then f64_to_i16_bang
      when {:f64, :i32} then f64_to_i32_bang
      when {:f64, :i64} then f64_to_i64_bang
      when {:f64, :f32} then f64_to_f32_bang
      when {:f64, :f64} then nop
      else                   node.raise "BUG: missing handling of unchecked_convert for #{obj_type} (#{node.name})"
      end
    when "binary"
      case node.name
      when "+"
        # TODO: don't assume Int32 + Int32
        accept_call_members(node)
        add_i32
        # when "-"  then binary_minus
        # when "*"  then binary_mult
      when "<"
        # TODO: don't assume Int32 + Int32
        accept_call_members(node)
        lt_i32
        # when "<=" then binary_le
        # when ">"  then binary_gt
        # when ">=" then binary_ge
      when "=="
        # TODO: don't assume Int32 + Int32
        accept_call_members(node)
        eq_i32
        # when "!=" then binary_neq
      else
        node.raise "BUG: missing handling of binary op #{node.name}"
      end
    when "pointer_new"
      accept_call_members(node)
      pointer_new
    when "pointer_malloc"
      node.args.first.accept self

      pointer_instance_type = node.obj.not_nil!.type.instance_type.as(PointerInstanceType)
      element_type = pointer_instance_type.element_type
      element_size = sizeof_type(element_type)

      pointer_malloc(element_size)
    when "pointer_set"
      # Accept in reverse order so that it's easier for the interpreter
      node.args.first.accept self
      node.obj.not_nil!.accept self
      pointer_set(sizeof_type(node.args.first))
    when "pointer_get"
      accept_call_members(node)
      pointer_get(sizeof_type(node.obj.not_nil!.type.as(PointerInstanceType).element_type))
    when "pointer_address"
      accept_call_members(node)
      pointer_address
    when "pointer_diff"
      accept_call_members(node)
      pointer_diff(sizeof_type(node.obj.not_nil!.type.as(PointerInstanceType).element_type))
    when "class"
      put_type node.obj.not_nil!.type
    when "object_crystal_type_id"
      put_i32 type_id(node.obj.not_nil!.type)
    else
      node.raise "BUG: missing handling of primitive #{body.name}"
    end
  end

  private def integer_or_float_kind(type)
    case type
    when IntegerType
      type.kind
    when FloatType
      type.kind
    else
      nil
    end
  end
end
