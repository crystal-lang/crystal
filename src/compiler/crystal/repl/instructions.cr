require "./repl"

Crystal::Repl::Instructions =
  {
    put_nil: {
      operands:   [] of Nil,
      pop_values: [] of Nil,
      push:       false,
      code:       nil,
    },
    put_false: {
      operands:   [] of Nil,
      pop_values: [] of Nil,
      push:       true,
      code:       0_u8,
    },
    put_true: {
      operands:   [] of Nil,
      pop_values: [] of Nil,
      push:       true,
      code:       1_u8,
    },
    put_i8: {
      operands:   [value : Int8],
      pop_values: [] of Nil,
      push:       true,
      code:       value,
    },
    put_i16: {
      operands:   [value : Int16],
      pop_values: [] of Nil,
      push:       true,
      code:       value,
    },
    put_i32: {
      operands:   [value : Int32],
      pop_values: [] of Nil,
      push:       true,
      code:       value,
    },
    put_i64: {
      operands:   [value : Int64],
      pop_values: [] of Nil,
      push:       true,
      code:       value,
    },
    add_i32: {
      operands:   [] of Nil,
      pop_values: [a : Int32, b : Int32],
      push:       true,
      code:       a + b,
    },
    lt_i32: {
      operands:   [] of Nil,
      pop_values: [a : Int32, b : Int32],
      push:       true,
      code:       a < b,
    },
    eq_i32: {
      operands:   [] of Nil,
      pop_values: [a : Int32, b : Int32],
      push:       true,
      code:       a == b,
    },
    i8_to_i16: {
      operands:   [] of Nil,
      pop_values: [value : Int8],
      push:       true,
      code:       value.to_i16,
    },
    i8_to_i32: {
      operands:   [] of Nil,
      pop_values: [value : Int8],
      push:       true,
      code:       value.to_i32,
    },
    i8_to_i64: {
      operands:   [] of Nil,
      pop_values: [value : Int8],
      push:       true,
      code:       value.to_i64,
    },
    i8_to_f32: {
      operands:   [] of Nil,
      pop_values: [value : Int8],
      push:       true,
      code:       value.to_f32,
    },
    i8_to_f64: {
      operands:   [] of Nil,
      pop_values: [value : Int8],
      push:       true,
      code:       value.to_f64,
    },
    u8_to_i16: {
      operands:   [] of Nil,
      pop_values: [value : UInt8],
      push:       true,
      code:       value.to_i16,
    },
    u8_to_i32: {
      operands:   [] of Nil,
      pop_values: [value : UInt8],
      push:       true,
      code:       value.to_i32,
    },
    u8_to_i64: {
      operands:   [] of Nil,
      pop_values: [value : UInt8],
      push:       true,
      code:       value.to_i64,
    },
    u8_to_f32: {
      operands:   [] of Nil,
      pop_values: [value : UInt8],
      push:       true,
      code:       value.to_f32,
    },
    u8_to_f64: {
      operands:   [] of Nil,
      pop_values: [value : UInt8],
      push:       true,
      code:       value.to_f64,
    },
    i16_to_i8_bang: {
      operands:   [] of Nil,
      pop_values: [value : Int16],
      push:       true,
      code:       value.to_i8!,
    },
    i16_to_i32: {
      operands:   [] of Nil,
      pop_values: [value : Int16],
      push:       true,
      code:       value.to_i32!,
    },
    i16_to_i64: {
      operands:   [] of Nil,
      pop_values: [value : Int16],
      push:       true,
      code:       value.to_i64,
    },
    i16_to_f32: {
      operands:   [] of Nil,
      pop_values: [value : Int16],
      push:       true,
      code:       value.to_f32,
    },
    i16_to_f64: {
      operands:   [] of Nil,
      pop_values: [value : Int16],
      push:       true,
      code:       value.to_f64,
    },
    u16_to_i32: {
      operands:   [] of Nil,
      pop_values: [value : UInt16],
      push:       true,
      code:       value.to_i32!,
    },
    u16_to_i64: {
      operands:   [] of Nil,
      pop_values: [value : UInt16],
      push:       true,
      code:       value.to_i64,
    },
    u16_to_f32: {
      operands:   [] of Nil,
      pop_values: [value : UInt16],
      push:       true,
      code:       value.to_f32,
    },
    u16_to_f64: {
      operands:   [] of Nil,
      pop_values: [value : UInt16],
      push:       true,
      code:       value.to_f64,
    },
    i32_to_i8_bang: {
      operands:   [] of Nil,
      pop_values: [value : Int32],
      push:       true,
      code:       value.to_i8!,
    },
    i32_to_i16_bang: {
      operands:   [] of Nil,
      pop_values: [value : Int32],
      push:       true,
      code:       value.to_u16!,
    },
    i32_to_i64: {
      operands:   [] of Nil,
      pop_values: [value : Int32],
      push:       true,
      code:       value.to_i64,
    },
    i32_to_f32: {
      operands:   [] of Nil,
      pop_values: [value : Int32],
      push:       true,
      code:       value.to_f32,
    },
    i32_to_f64: {
      operands:   [] of Nil,
      pop_values: [value : Int32],
      push:       true,
      code:       value.to_f64,
    },
    u32_to_i64: {
      operands:   [] of Nil,
      pop_values: [value : UInt32],
      push:       true,
      code:       value.to_i64,
    },
    u32_to_f32: {
      operands:   [] of Nil,
      pop_values: [value : UInt32],
      push:       true,
      code:       value.to_f32,
    },
    u32_to_f64: {
      operands:   [] of Nil,
      pop_values: [value : UInt32],
      push:       true,
      code:       value.to_f64,
    },
    i64_to_i8_bang: {
      operands:   [] of Nil,
      pop_values: [value : Int64],
      push:       true,
      code:       value.to_i8!,
    },
    i64_to_i16_bang: {
      operands:   [] of Nil,
      pop_values: [value : Int64],
      push:       true,
      code:       value.to_u16!,
    },
    i64_to_i32_bang: {
      operands:   [] of Nil,
      pop_values: [value : Int64],
      push:       true,
      code:       value.to_i32!,
    },
    i64_to_f32: {
      operands:   [] of Nil,
      pop_values: [value : Int64],
      push:       true,
      code:       value.to_f32,
    },
    i64_to_f64: {
      operands:   [] of Nil,
      pop_values: [value : Int64],
      push:       true,
      code:       value.to_f64,
    },
    u64_to_f32: {
      operands:   [] of Nil,
      pop_values: [value : UInt64],
      push:       true,
      code:       value.to_f32,
    },
    u64_to_f64: {
      operands:   [] of Nil,
      pop_values: [value : UInt64],
      push:       true,
      code:       value.to_f64,
    },
    f32_to_u8_bang: {
      operands:   [] of Nil,
      pop_values: [value : Float32],
      push:       true,
      code:       value.to_u8!,
    },
    f32_to_i8_bang: {
      operands:   [] of Nil,
      pop_values: [value : Float32],
      push:       true,
      code:       value.to_i8!,
    },
    f32_to_u16_bang: {
      operands:   [] of Nil,
      pop_values: [value : Float32],
      push:       true,
      code:       value.to_u16!,
    },
    f32_to_i16_bang: {
      operands:   [] of Nil,
      pop_values: [value : Float32],
      push:       true,
      code:       value.to_i16!,
    },
    f32_to_u32_bang: {
      operands:   [] of Nil,
      pop_values: [value : Float32],
      push:       true,
      code:       value.to_u32!,
    },
    f32_to_i32_bang: {
      operands:   [] of Nil,
      pop_values: [value : Float32],
      push:       true,
      code:       value.to_i32!,
    },
    f32_to_u64_bang: {
      operands:   [] of Nil,
      pop_values: [value : Float32],
      push:       true,
      code:       value.to_u64!,
    },
    f32_to_i64_bang: {
      operands:   [] of Nil,
      pop_values: [value : Float32],
      push:       true,
      code:       value.to_i64!,
    },
    f32_to_f64: {
      operands:   [] of Nil,
      pop_values: [value : Float32],
      push:       true,
      code:       value.to_f64,
    },
    f64_to_u8_bang: {
      operands:   [] of Nil,
      pop_values: [value : Float64],
      push:       true,
      code:       value.to_u8!,
    },
    f64_to_i8_bang: {
      operands:   [] of Nil,
      pop_values: [value : Float64],
      push:       true,
      code:       value.to_i8!,
    },
    f64_to_u16_bang: {
      operands:   [] of Nil,
      pop_values: [value : Float64],
      push:       true,
      code:       value.to_u16!,
    },
    f64_to_i16_bang: {
      operands:   [] of Nil,
      pop_values: [value : Float64],
      push:       true,
      code:       value.to_i16!,
    },
    f64_to_u32_bang: {
      operands:   [] of Nil,
      pop_values: [value : Float64],
      push:       true,
      code:       value.to_u32!,
    },
    f64_to_i32_bang: {
      operands:   [] of Nil,
      pop_values: [value : Float64],
      push:       true,
      code:       value.to_i32!,
    },
    f64_to_u64_bang: {
      operands:   [] of Nil,
      pop_values: [value : Float64],
      push:       true,
      code:       value.to_u64!,
    },
    f64_to_i64_bang: {
      operands:   [] of Nil,
      pop_values: [value : Float64],
      push:       true,
      code:       value.to_i64!,
    },
    f64_to_f32_bang: {
      operands:   [] of Nil,
      pop_values: [value : Float64],
      push:       true,
      code:       value.to_f32!,
    },

    # binary_plus: {
    #   operands:   [] of Nil,
    #   pop_values: [left, right],
    #   push:       true,
    #   code:       binary_op!(:+),
    # },
    # binary_minus: {
    #   operands:   [] of Nil,
    #   pop_values: [left, right],
    #   push:       true,
    #   code:       binary_op!(:-),
    # },
    # binary_mult: {
    #   operands:   [] of Nil,
    #   pop_values: [left, right],
    #   push:       true,
    #   code:       binary_op!(:*),
    # },
    # binary_lt: {
    #   operands:   [] of Nil,
    #   pop_values: [left, right],
    #   push:       true,
    #   code:       binary_cmp!(:<),
    # },
    # binary_le: {
    #   operands:   [] of Nil,
    #   pop_values: [left, right],
    #   push:       true,
    #   code:       binary_cmp!(:<=),
    # },
    # binary_gt: {
    #   operands:   [] of Nil,
    #   pop_values: [left, right],
    #   push:       true,
    #   code:       binary_cmp!(:>),
    # },
    # binary_ge: {
    #   operands:   [] of Nil,
    #   pop_values: [left, right],
    #   push:       true,
    #   code:       binary_cmp!(:>=),
    # },
    # binary_eq: {
    #   operands:   [] of Nil,
    #   pop_values: [left, right],
    #   push:       true,
    #   code:       binary_eq!(:==),
    # },
    # binary_neq: {
    #   operands:   [] of Nil,
    #   pop_values: [left, right],
    #   push:       true,
    #   code:       binary_eq!(:!=),
    # },
    logical_not: {
      operands:   [] of Nil,
      pop_values: [value : Bool],
      push:       true,
      code:       !value,
    },

    pointer_malloc: {
      operands:   [element_size : Int32] of Nil,
      pop_values: [size : UInt64],
      push:       true,
      code:       Pointer(UInt8).malloc(size * element_size),
    },
    pointer_set: {
      operands:   [element_size : Int32] of Nil,
      pop_values: [pointer : Pointer(UInt8)] of Nil,
      push:       false,
      code:       stack_copy_to(pointer, element_size),
    },
    pointer_get: {
      operands:   [element_size : Int32] of Nil,
      pop_values: [pointer : Pointer(UInt8)] of Nil,
      push:       false,
      code:       stack_move_from(pointer, element_size),
    },
    pointer_new: {
      operands:   [] of Nil,
      pop_values: [type_id : Int32, address : UInt64],
      push:       true,
      code:       Pointer(UInt8).new(address),
    },
    pointer_address: {
      operands:   [] of Nil,
      pop_values: [pointer : Pointer(UInt8)],
      push:       true,
      code:       pointer.address,
    },
    pointer_diff: {
      operands:   [element_size : Int32] of Nil,
      pop_values: [pointer1 : Pointer(UInt8), pointer2 : Pointer(UInt8)],
      push:       true,
      code:       (pointer1.address - pointer2.address) // element_size,
    },
    set_local: {
      operands:    [index : Int32, size : Int32],
      pop_values:  [] of Nil,
      push:        false,
      code:        set_local_var(index, size),
      disassemble: {
        index: "#{local_vars.index_to_name(index)}@#{index}",
      },
    },
    get_local: {
      operands:    [index : Int32, size : Int32],
      pop_values:  [] of Nil,
      push:        false,
      code:        get_local_var(index, size),
      disassemble: {
        index: "#{local_vars.index_to_name(index)}@#{index}",
      },
    },
    pop: {
      operands:   [size : Int32] of Nil,
      pop_values: [] of Nil,
      push:       false,
      code:       stack_pop_size(size),
    },
    branch_if: {
      operands:   [index : Int32],
      pop_values: [cond : Bool],
      push:       false,
      code:       (set_ip(index) if cond),
    },
    branch_unless: {
      operands:   [index : Int32],
      pop_values: [cond : Bool],
      push:       false,
      code:       (set_ip(index) unless cond),
    },
    jump: {
      operands:   [index : Int32],
      pop_values: [] of Nil,
      push:       false,
      code:       set_ip(index),
    },
    pointerof_var: {
      operands:   [index : Int32],
      pop_values: [] of Nil,
      push:       true,
      code:       get_local_var_pointer(index),
    },
    leave: {
      operands:   [] of Nil,
      pop_values: [] of Nil,
      push:       false,
      code:       (break),
    },
  }

private macro binary_op!(op)
  result = left.value.as(Int::Primitive | Float::Primitive) {{op.id}}
           right.value.as(Int::Primitive | Float::Primitive)
  type =
    case result
    when Int8    then @program.int8
    when UInt8   then @program.uint8
    when Int16   then @program.int16
    when UInt16  then @program.uint16
    when Int32   then @program.int32
    when UInt32  then @program.uint32
    when Int64   then @program.int64
    when UInt64  then @program.uint64
    when Float32 then @program.float32
    when Float64 then @program.float64
    else
      raise "Unexpected result type from binary op: #{result.class}"
    end
  Value.new(result, type)
end

private macro binary_cmp!(op)
  result = left.value.as(Int::Primitive | Float::Primitive) {{op.id}}
    right.value.as(Int::Primitive | Float::Primitive)

  Value.new(result, @program.bool)
end

private macro binary_eq!(op)
  result = left.value {{op.id}} right.value

  Value.new(result, @program.bool)
end

# {% puts "Remaining opcodes: #{256 - Crystal::Repl::Instructions.size}" %}
