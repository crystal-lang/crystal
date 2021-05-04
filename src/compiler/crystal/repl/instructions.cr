require "./repl"

Crystal::Repl::Instructions =
  {
    put_nil: {
      operands:   [] of Nil,
      pop_values: [] of Nil,
      push:       true,
      code:       Value.new(nil, @program.nil_type),
    },
    put_false: {
      operands:   [] of Nil,
      pop_values: [] of Nil,
      push:       true,
      code:       Value.new(false, @program.bool),
    },
    put_true: {
      operands:   [] of Nil,
      pop_values: [] of Nil,
      push:       true,
      code:       Value.new(true, @program.bool),
    },
    binary_plus: {
      operands:   [] of Nil,
      pop_values: [left, right],
      push:       true,
      code:       binary_op!(:+),
    },
    binary_minus: {
      operands:   [] of Nil,
      pop_values: [left, right],
      push:       true,
      code:       binary_op!(:-),
    },
    binary_mult: {
      operands:   [] of Nil,
      pop_values: [left, right],
      push:       true,
      code:       binary_op!(:*),
    },
    binary_lt: {
      operands:   [] of Nil,
      pop_values: [left, right],
      push:       true,
      code:       binary_cmp!(:<),
    },
    binary_le: {
      operands:   [] of Nil,
      pop_values: [left, right],
      push:       true,
      code:       binary_cmp!(:<=),
    },
    binary_gt: {
      operands:   [] of Nil,
      pop_values: [left, right],
      push:       true,
      code:       binary_cmp!(:>),
    },
    binary_ge: {
      operands:   [] of Nil,
      pop_values: [left, right],
      push:       true,
      code:       binary_cmp!(:>=),
    },
    binary_eq: {
      operands:   [] of Nil,
      pop_values: [left, right],
      push:       true,
      code:       binary_eq!(:==),
    },
    binary_neq: {
      operands:   [] of Nil,
      pop_values: [left, right],
      push:       true,
      code:       binary_eq!(:!=),
    },
    pointer_malloc: {
      operands:   [] of Nil,
      pop_values: [type, size],
      push:       true,
      code:       begin
        pointer = Pointer(Value).malloc(size.value.as(UInt64))
        Value.new(pointer, type.value.as(Type).instance_type)
      end,
    },
    pointer_set: {
      operands:   [] of Nil,
      pop_values: [pointer, value],
      push:       true,
      code:       begin
        pointer.value.as(PointerWrapper).pointer.value = value
        value
      end,
    },
    pointer_get: {
      operands:   [] of Nil,
      pop_values: [pointer],
      push:       true,
      code:       begin
        pointer.value.as(PointerWrapper).pointer.value
      end,
    },
    put_object: {
      operands:   [value : Value],
      pop_values: [] of Nil,
      push:       true,
      code:       value,
    },
    set_local: {
      operands:    [index : Int32],
      pop_values:  [] of Nil,
      push:        false,
      code:        set_local_var(index, stack_last),
      disassemble: {
        index: "#{local_vars.index_to_name(index)}@#{index}",
      },
    },
    get_local: {
      operands:    [index : Int32],
      pop_values:  [] of Nil,
      push:        true,
      code:        get_local_var(index),
      disassemble: {
        index: "#{local_vars.index_to_name(index)}@#{index}",
      },
    },
    pop: {
      operands:   [] of Nil,
      pop_values: [discard],
      push:       false,
      code:       nil,
    },
    branch_if: {
      operands:   [index : Int32],
      pop_values: [cond],
      push:       false,
      code:       (set_ip(index) if cond.value.as(Bool)),
    },
    branch_unless: {
      operands:   [index : Int32],
      pop_values: [cond],
      push:       false,
      code:       (set_ip(index) unless cond.value.as(Bool)),
    },
    jump: {
      operands:   [index : Int32],
      pop_values: [] of Nil,
      push:       false,
      code:       set_ip(index),
    },
    leave: {
      operands:   [] of Nil,
      pop_values: [value],
      push:       false,
      code:       (return value),
    },
    pointerof_var: {
      operands:   [index : Int32],
      pop_values: [] of Nil,
      push:       true,
      code:       get_local_var_pointer(index),
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
