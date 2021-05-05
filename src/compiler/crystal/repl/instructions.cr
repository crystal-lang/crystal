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
    pointer_malloc: {
      operands:   [] of Nil,
      pop_values: [type : Type, size : UInt64],
      push:       true,
      code:       begin
        pointer_instance_type = type.instance_type.as(PointerInstanceType)
        element_type = pointer_instance_type.element_type
        element_size = sizeof_type(element_type)
        Pointer(UInt8).malloc(size * element_size)
      end,
    },
    pointer_set: {
      operands:   [value_size : Int32] of Nil,
      pop_values: [] of Nil,
      push:       false,
      code:       begin
        # TODO: clean up stack
        # TODO: abstract this better?
        stack_before_value = stack - value_size
        stack_before_pointer = stack_before_value - sizeof(Pointer(UInt8))

        pointer = stack_before_pointer.as(Pointer(Pointer(UInt8))).value
        pointer.copy_from(stack_before_value, value_size)

        stack = stack_before_pointer
        stack_copy_from(stack_before_value, value_size)
      end,
    },
    pointer_get: {
      operands:   [value_size : Int32] of Nil,
      pop_values: [pointer : Pointer(UInt8)] of Nil,
      push:       false,
      code:       stack_copy_from(pointer, value_size),
    },
    pointer_new: {
      operands:   [] of Nil,
      pop_values: [type : Type, address : UInt64],
      push:       true,
      code:       Pointer(UInt8).new(address),
    },
    pointer_address: {
      operands:   [] of Nil,
      pop_values: [pointer : Pointer(UInt8)],
      push:       true,
      code:       pointer.address,
    },
    # pointer_diff: {
    #   operands:   [] of Nil,
    #   pop_values: [pointer1, pointer2],
    #   push:       true,
    #   code:       Value.new(
    #     pointer1.value.as(PointerWrapper).pointer -
    #     pointer2.value.as(PointerWrapper).pointer,
    #     @program.int64,
    #   ),
    # },
    # put_object: {
    #   operands:   [value : Value],
    #   pop_values: [] of Nil,
    #   push:       true,
    #   code:       value,
    # },
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
