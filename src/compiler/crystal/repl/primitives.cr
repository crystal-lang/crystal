require "./compiler"

class Crystal::Repl::Compiler
  private def visit_primitive(node, body)
    case body.name
    when "unchecked_convert"
      obj = node.obj.not_nil!
      obj.accept self

      obj_type = obj.type
      case obj_type
      when IntegerType
        case obj_type.kind
        when :i8
          case node.name
          when "to_u8!", "to_i8!"                     then nop
          when "to_u16!", "to_i16!"                   then i8_to_i16
          when "to_u32!", "to_i32!", "to_u!", "to_i!" then i8_to_i32
          when "to_u64!", "to_i64!"                   then i8_to_i64
          when "to_f32!"                              then i8_to_f32
          when "to_f64!"                              then i8_to_f64
          else                                             node.raise "BUG: missing handling of unchecked_convert for #{obj_type} (#{node.name})"
          end
        when :u8
          case node.name
          when "to_u8!", "to_i8!"                     then nop
          when "to_u16!", "to_i16!"                   then u8_to_i16
          when "to_u32!", "to_i32!", "to_u!", "to_i!" then u8_to_i32
          when "to_u64!", "to_i64!"                   then u8_to_i64
          when "to_f32!"                              then u8_to_f32
          when "to_f64!"                              then u8_to_f64
          else
            node.raise "BUG: missing handling of unchecked_convert for #{obj_type} (#{node.name})"
          end
        when :i16
          case node.name
          when "to_u8!", "to_i8!"                     then i16_to_i8_bang
          when "to_u16!", "to_i16!"                   then nop
          when "to_u32!", "to_i32!", "to_u!", "to_i!" then i16_to_i32
          when "to_u64!", "to_i64!"                   then i16_to_i64
          when "to_f32!"                              then i16_to_f32
          when "to_f64!"                              then i16_to_f64
          else
            node.raise "BUG: missing handling of unchecked_convert for #{obj_type} (#{node.name})"
          end
        when :u16
          case node.name
          when "to_u8!", "to_i8!"                     then i16_to_i8_bang
          when "to_u16!", "to_i16!"                   then nop
          when "to_u32!", "to_i32!", "to_u!", "to_i!" then u16_to_i32
          when "to_u64!", "to_i64!"                   then u16_to_i64
          when "to_f32!"                              then u16_to_f32
          when "to_f64!"                              then u16_to_f64
          else
            node.raise "BUG: missing handling of unchecked_convert for #{obj_type} (#{node.name})"
          end
        when :i32
          case node.name
          when "to_u8!", "to_i8!"                     then i32_to_i8_bang
          when "to_u16!", "to_i16!"                   then i32_to_i16_bang
          when "to_u32!", "to_i32!", "to_u!", "to_i!" then nop
          when "to_u64!", "to_i64!"                   then i32_to_i64
          when "to_f32!"                              then i32_to_f32
          when "to_f64!"                              then i32_to_f64
          else
            node.raise "BUG: missing handling of unchecked_convert for #{obj_type} (#{node.name})"
          end
        when :u32
          case node.name
          when "to_u8!", "to_i8!"                     then i32_to_i8_bang
          when "to_u16!", "to_i16!"                   then i32_to_i16_bang
          when "to_u32!", "to_i32!", "to_u!", "to_i!" then nop
          when "to_u64!", "to_i64!"                   then u32_to_i64
          when "to_f32!"                              then u32_to_f32
          when "to_f64!"                              then u32_to_f64
          else
            node.raise "BUG: missing handling of unchecked_convert for #{obj_type} (#{node.name})"
          end
        when :i64
          case node.name
          when "to_u8!", "to_i8!"                     then i64_to_i8_bang
          when "to_u16!", "to_i16!"                   then i64_to_i16_bang
          when "to_u32!", "to_i32!", "to_u!", "to_i!" then i64_to_i32_bang
          when "to_u64!", "to_i64!"                   then nop
          when "to_f32!"                              then i64_to_f32
          when "to_f64!"                              then i64_to_f64
          else
            node.raise "BUG: missing handling of unchecked_convert for #{obj_type} (#{node.name})"
          end
        when :u64
          case node.name
          when "to_u8!", "to_i8!"                     then i64_to_i8_bang
          when "to_u16!", "to_i16!"                   then i64_to_i16_bang
          when "to_u32!", "to_i32!", "to_u!", "to_i!" then i64_to_i32_bang
          when "to_u64!", "to_i64!"                   then nop
          when "to_f32!"                              then u64_to_f32
          when "to_f64!"                              then u64_to_f64
          else
            node.raise "BUG: missing handling of unchecked_convert for #{obj_type} (#{node.name})"
          end
        else
          node.raise "BUG: missing handling of unchecked_convert for #{obj_type} (#{node.name})"
        end
      when FloatType
        case obj_type.kind
        when :f32
          case node.name
          when "to_u8!"           then f32_to_u8_bang
          when "to_i8!"           then f32_to_i8_bang
          when "to_u16!"          then f32_to_u16_bang
          when "to_i16!"          then f32_to_i16_bang
          when "to_u32!", "to_u!" then f32_to_u32_bang
          when "to_i32!", "to_i!" then f32_to_i32_bang
          when "to_u64!"          then f32_to_u64_bang
          when "to_i64!"          then f32_to_i64_bang
          when "to_f32!"          then nop
          when "to_f64!"          then f32_to_f64
          else
            node.raise "BUG: missing handling of unchecked_convert for #{obj_type} (#{node.name})"
          end
        when :f64
          case node.name
          when "to_u8!"           then f64_to_u8_bang
          when "to_i8!"           then f64_to_i8_bang
          when "to_u16!"          then f64_to_u16_bang
          when "to_i16!"          then f64_to_i16_bang
          when "to_u32!", "to_u!" then f64_to_u32_bang
          when "to_i32!", "to_i!" then f64_to_i32_bang
          when "to_u64!"          then f64_to_u64_bang
          when "to_i64!"          then f64_to_i64_bang
          when "to_f32!"          then f64_to_f32_bang
          when "to_f64!"          then nop
          else
            node.raise "BUG: missing handling of unchecked_convert for #{obj_type} (#{node.name})"
          end
        else
          node.raise "BUG: missing handling of unchecked_convert for #{obj_type} (#{node.name})"
        end
      else
        node.raise "BUG: missing handling of unchecked_convert for #{obj_type} (#{node.name})"
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
end
