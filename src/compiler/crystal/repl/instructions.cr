require "./repl"

# Summary:
# - Put: 7
# - Conversions: 21
# - Math: 36 / 76?
# - Comparison: 26 / 40?
# - Not: 1
# - Pointers: 9
# - Local variables: 2
# - Stack manipulation: 5
# - Jumps: 3
# - Pointerof: 2
# - Calls: 5
# - Allocate: 2
# - Instance vars: 3
# - Unions: 4
# - Tuples: 1
# - Procs: 1
# - Overrides: 5
# ------------------------
# - Total: 132
# - Remaining: 124

Crystal::Repl::Instructions =
  {
    # <<< Put (7)
    put_nil: {
      operands:   [] of Nil,
      pop_values: [] of Nil,
      push:       false,
      code:       nil,
    },
    put_i64: {
      operands:   [value : Int64],
      pop_values: [] of Nil,
      push:       true,
      code:       value,
    },
    # >>> Put (7)

    # <<< Conversions (21)
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
    sign_extend: {
      operands:   [amount : Int32] of Nil,
      pop_values: [] of Nil,
      push:       false,
      code:       begin
        if (stack - amount - 1).as(Int8*).value < 0
          Intrinsics.memset((stack - amount).as(Void*), 255_u8, amount, false)
        else
          (stack - amount).clear(amount)
        end
      end,
    },
    zero_extend: {
      operands:   [amount : Int32] of Nil,
      pop_values: [] of Nil,
      push:       false,
      code:       (stack - amount).clear(amount),
    },
    # >>> Conversions (21)

    # <<< Math (36)
    add_i32: {
      operands:   [] of Nil,
      pop_values: [a : Int32, b : Int32],
      push:       true,
      code:       a + b,
    },
    add_wrap_i32: {
      operands:   [] of Nil,
      pop_values: [a : Int32, b : Int32],
      push:       true,
      code:       a &+ b,
    },
    sub_i32: {
      operands:   [] of Nil,
      pop_values: [a : Int32, b : Int32],
      push:       true,
      code:       a - b,
    },
    sub_wrap_i32: {
      operands:   [] of Nil,
      pop_values: [a : Int32, b : Int32],
      push:       true,
      code:       a &- b,
    },
    mul_i32: {
      operands:   [] of Nil,
      pop_values: [a : Int32, b : Int32],
      push:       true,
      code:       a * b,
    },
    mul_wrap_i32: {
      operands:   [] of Nil,
      pop_values: [a : Int32, b : Int32],
      push:       true,
      code:       a &* b,
    },
    xor_i32: {
      operands:   [] of Nil,
      pop_values: [a : Int32, b : Int32],
      push:       true,
      code:       a ^ b,
    },
    or_i32: {
      operands:   [] of Nil,
      pop_values: [a : Int32, b : Int32],
      push:       true,
      code:       a | b,
    },
    and_i32: {
      operands:   [] of Nil,
      pop_values: [a : Int32, b : Int32],
      push:       true,
      code:       a & b,
    },
    unsafe_shr_i32: {
      operands:   [] of Nil,
      pop_values: [a : Int32, b : Int32],
      push:       true,
      code:       a.unsafe_shr(b),
    },
    unsafe_shl_i32: {
      operands:   [] of Nil,
      pop_values: [a : Int32, b : Int32],
      push:       true,
      code:       a.unsafe_shl(b),
    },
    unsafe_div_i32: {
      operands:   [] of Nil,
      pop_values: [a : Int32, b : Int32],
      push:       true,
      code:       a.unsafe_div(b),
    },
    unsafe_mod_i32: {
      operands:   [] of Nil,
      pop_values: [a : Int32, b : Int32],
      push:       true,
      code:       a.unsafe_mod(b),
    },
    add_u32: {
      operands:   [] of Nil,
      pop_values: [a : UInt32, b : UInt32],
      push:       true,
      code:       a + b,
    },
    sub_u32: {
      operands:   [] of Nil,
      pop_values: [a : UInt32, b : UInt32],
      push:       true,
      code:       a - b,
    },
    mul_u32: {
      operands:   [] of Nil,
      pop_values: [a : UInt32, b : UInt32],
      push:       true,
      code:       a * b,
    },
    unsafe_shr_u32: {
      operands:   [] of Nil,
      pop_values: [a : UInt32, b : UInt32],
      push:       true,
      code:       a.unsafe_shr(b),
    },
    unsafe_div_u32: {
      operands:   [] of Nil,
      pop_values: [a : UInt32, b : UInt32],
      push:       true,
      code:       a.unsafe_div(b),
    },
    unsafe_mod_u32: {
      operands:   [] of Nil,
      pop_values: [a : UInt32, b : UInt32],
      push:       true,
      code:       a.unsafe_mod(b),
    },
    add_i64: {
      operands:   [] of Nil,
      pop_values: [a : Int64, b : Int64],
      push:       true,
      code:       a + b,
    },
    add_wrap_i64: {
      operands:   [] of Nil,
      pop_values: [a : Int64, b : Int64],
      push:       true,
      code:       a &+ b,
    },
    sub_i64: {
      operands:   [] of Nil,
      pop_values: [a : Int64, b : Int64],
      push:       true,
      code:       a - b,
    },
    sub_wrap_i64: {
      operands:   [] of Nil,
      pop_values: [a : Int64, b : Int64],
      push:       true,
      code:       a &- b,
    },
    mul_i64: {
      operands:   [] of Nil,
      pop_values: [a : Int64, b : Int64],
      push:       true,
      code:       a * b,
    },
    mul_wrap_i64: {
      operands:   [] of Nil,
      pop_values: [a : Int64, b : Int64],
      push:       true,
      code:       a &* b,
    },
    xor_i64: {
      operands:   [] of Nil,
      pop_values: [a : Int64, b : Int64],
      push:       true,
      code:       a ^ b,
    },
    or_i64: {
      operands:   [] of Nil,
      pop_values: [a : Int64, b : Int64],
      push:       true,
      code:       a | b,
    },
    and_i64: {
      operands:   [] of Nil,
      pop_values: [a : Int64, b : Int64],
      push:       true,
      code:       a & b,
    },
    unsafe_shr_i64: {
      operands:   [] of Nil,
      pop_values: [a : Int64, b : Int64],
      push:       true,
      code:       a.unsafe_shr(b),
    },
    unsafe_shl_i64: {
      operands:   [] of Nil,
      pop_values: [a : Int64, b : Int64],
      push:       true,
      code:       a.unsafe_shl(b),
    },
    unsafe_div_i64: {
      operands:   [] of Nil,
      pop_values: [a : Int64, b : Int64],
      push:       true,
      code:       a.unsafe_div(b),
    },
    unsafe_mod_i64: {
      operands:   [] of Nil,
      pop_values: [a : Int64, b : Int64],
      push:       true,
      code:       a.unsafe_mod(b),
    },
    add_u64: {
      operands:   [] of Nil,
      pop_values: [a : UInt64, b : UInt64],
      push:       true,
      code:       a + b,
    },
    sub_u64: {
      operands:   [] of Nil,
      pop_values: [a : UInt64, b : UInt64],
      push:       true,
      code:       a - b,
    },
    mul_u64: {
      operands:   [] of Nil,
      pop_values: [a : UInt64, b : UInt64],
      push:       true,
      code:       a * b,
    },
    unsafe_shr_u64: {
      operands:   [] of Nil,
      pop_values: [a : UInt64, b : UInt64],
      push:       true,
      code:       a.unsafe_shr(b),
    },
    unsafe_div_u64: {
      operands:   [] of Nil,
      pop_values: [a : Int64, b : Int64],
      push:       true,
      code:       a.unsafe_div(b),
    },
    unsafe_mod_u64: {
      operands:   [] of Nil,
      pop_values: [a : Int64, b : Int64],
      push:       true,
      code:       a.unsafe_mod(b),
    },
    add_f64: {
      operands:   [] of Nil,
      pop_values: [a : Float64, b : Float64],
      push:       true,
      code:       a + b,
    },
    sub_f64: {
      operands:   [] of Nil,
      pop_values: [a : Float64, b : Float64],
      push:       true,
      code:       a - b,
    },
    mul_f64: {
      operands:   [] of Nil,
      pop_values: [a : Float64, b : Float64],
      push:       true,
      code:       a * b,
    },
    div_f64: {
      operands:   [] of Nil,
      pop_values: [a : Float64, b : Float64],
      push:       true,
      code:       a / b,
    },
    add_u64_i64: {
      operands:   [] of Nil,
      pop_values: [a : UInt64, b : Int64],
      push:       true,
      code:       a + b,
    },
    sub_u64_i64: {
      operands:   [] of Nil,
      pop_values: [a : UInt64, b : Int64],
      push:       true,
      code:       a - b,
    },
    mul_u64_i64: {
      operands:   [] of Nil,
      pop_values: [a : UInt64, b : Int64],
      push:       true,
      code:       a * b,
    },
    unsafe_shr_u64_i64: {
      operands:   [] of Nil,
      pop_values: [a : UInt64, b : Int64],
      push:       true,
      code:       a.unsafe_shr(b),
    },
    unsafe_div_u64_i64: {
      operands:   [] of Nil,
      pop_values: [a : UInt64, b : Int64],
      push:       true,
      code:       a.unsafe_div(b),
    },
    unsafe_mod_u64_i64: {
      operands:   [] of Nil,
      pop_values: [a : UInt64, b : Int64],
      push:       true,
      code:       a.unsafe_mod(b),
    },
    add_i64_u64: {
      operands:   [] of Nil,
      pop_values: [a : Int64, b : UInt64],
      push:       true,
      code:       a + b,
    },
    sub_i64_u64: {
      operands:   [] of Nil,
      pop_values: [a : Int64, b : UInt64],
      push:       true,
      code:       a - b,
    },
    mul_i64_u64: {
      operands:   [] of Nil,
      pop_values: [a : Int64, b : UInt64],
      push:       true,
      code:       a * b,
    },
    unsafe_shr_i64_u64: {
      operands:   [] of Nil,
      pop_values: [a : Int64, b : UInt64],
      push:       true,
      code:       a.unsafe_shr(b),
    },
    unsafe_div_i64_u64: {
      operands:   [] of Nil,
      pop_values: [a : Int64, b : UInt64],
      push:       true,
      code:       a.unsafe_div(b),
    },
    unsafe_mod_i64_u64: {
      operands:   [] of Nil,
      pop_values: [a : Int64, b : UInt64],
      push:       true,
      code:       a.unsafe_mod(b),
    },
    # >>> Math (36)

    # <<< Comparisons (18)
    cmp_i8: {
      operands:   [] of Nil,
      pop_values: [a : Int8, b : Int8],
      push:       true,
      code:       a == b ? 0 : (a < b ? -1 : 1),
    },
    cmp_u8: {
      operands:   [] of Nil,
      pop_values: [a : UInt8, b : UInt8],
      push:       true,
      code:       a == b ? 0 : (a < b ? -1 : 1),
    },
    cmp_i16: {
      operands:   [] of Nil,
      pop_values: [a : Int16, b : Int16],
      push:       true,
      code:       a == b ? 0 : (a < b ? -1 : 1),
    },
    cmp_u16: {
      operands:   [] of Nil,
      pop_values: [a : UInt16, b : UInt16],
      push:       true,
      code:       a == b ? 0 : (a < b ? -1 : 1),
    },
    cmp_i32: {
      operands:   [] of Nil,
      pop_values: [a : Int32, b : Int32],
      push:       true,
      code:       a == b ? 0 : (a < b ? -1 : 1),
    },
    cmp_u32: {
      operands:   [] of Nil,
      pop_values: [a : UInt32, b : UInt32],
      push:       true,
      code:       a == b ? 0 : (a < b ? -1 : 1),
    },
    cmp_i64: {
      operands:   [] of Nil,
      pop_values: [a : Int64, b : Int64],
      push:       true,
      code:       a == b ? 0 : (a < b ? -1 : 1),
    },
    cmp_u64: {
      operands:   [] of Nil,
      pop_values: [a : UInt64, b : UInt64],
      push:       true,
      code:       a == b ? 0 : (a < b ? -1 : 1),
    },
    cmp_u64_i64: {
      operands:   [] of Nil,
      pop_values: [a : UInt64, b : Int64],
      push:       true,
      code:       a == b ? 0 : (a < b ? -1 : 1),
    },
    cmp_i64_u64: {
      operands:   [] of Nil,
      pop_values: [a : Int64, b : UInt64],
      push:       true,
      code:       a == b ? 0 : (a < b ? -1 : 1),
    },
    cmp_f32: {
      operands:   [] of Nil,
      pop_values: [a : Float32, b : Float32],
      push:       true,
      code:       a == b ? 0 : (a < b ? -1 : 1),
    },
    cmp_f64: {
      operands:   [] of Nil,
      pop_values: [a : Float64, b : Float64],
      push:       true,
      code:       a == b ? 0 : (a < b ? -1 : 1),
    },
    cmp_eq: {
      operands:   [] of Nil,
      pop_values: [cmp : Int32],
      push:       true,
      code:       cmp == 0,
    },
    cmp_neq: {
      operands:   [] of Nil,
      pop_values: [cmp : Int32],
      push:       true,
      code:       cmp != 0,
    },
    cmp_lt: {
      operands:   [] of Nil,
      pop_values: [cmp : Int32],
      push:       true,
      code:       cmp < 0,
    },
    cmp_le: {
      operands:   [] of Nil,
      pop_values: [cmp : Int32],
      push:       true,
      code:       cmp <= 0,
    },
    cmp_gt: {
      operands:   [] of Nil,
      pop_values: [cmp : Int32],
      push:       true,
      code:       cmp > 0,
    },
    cmp_ge: {
      operands:   [] of Nil,
      pop_values: [cmp : Int32],
      push:       true,
      code:       cmp >= 0,
    },
    # <<< Comparisons (18)

    # <<< Not (1)
    logical_not: {
      operands:   [] of Nil,
      pop_values: [value : Bool],
      push:       true,
      code:       !value,
    },
    # >>> Not (1)

    # <<< Pointers (9)
    pointer_malloc: {
      operands:   [element_size : Int32] of Nil,
      pop_values: [size : UInt64],
      push:       true,
      code:       Pointer(Void).malloc(size * element_size).as(UInt8*),
    },
    pointer_realloc: {
      operands:   [element_size : Int32] of Nil,
      pop_values: [pointer : Pointer(UInt8), size : UInt64],
      push:       true,
      code:       pointer.realloc(size * element_size),
    },
    pointer_set: {
      operands:   [element_size : Int32] of Nil,
      pop_values: [pointer : Pointer(UInt8)] of Nil,
      push:       false,
      code:       stack_move_to(pointer, element_size),
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
    pointer_add: {
      operands:   [element_size : Int32] of Nil,
      pop_values: [pointer : Pointer(UInt8), offset : Int64],
      push:       true,
      code:       pointer + (offset * element_size),
    },
    pointer_is_not_null: {
      operands:   [] of Nil,
      pop_values: [pointer : Pointer(UInt8)],
      push:       true,
      code:       !pointer.null?,
    },
    # >>> Pointers (9)

    # <<< Local variables (2)
    set_local: {
      operands:    [index : Int32, size : Int32],
      pop_values:  [] of Nil,
      push:        false,
      code:        set_local_var(index, size),
      disassemble: {
        index: "#{node.is_a?(Var) ? node : node.not_nil!.as(Assign).target}@#{index}",
      },
    },
    get_local: {
      operands:    [index : Int32, size : Int32],
      pop_values:  [] of Nil,
      push:        false,
      code:        get_local_var(index, size),
      disassemble: {
        index: "#{node.not_nil!}@#{index}",
      },
    },
    # >>> Local variables (2)

    # <<< Instance vars (3)
    get_self_ivar: {
      operands:   [offset : Int32, size : Int32],
      pop_values: [] of Nil,
      push:       false,
      code:       stack_move_from(self_class_pointer + offset, size),
    },
    set_self_ivar: {
      operands:   [offset : Int32, size : Int32],
      pop_values: [] of Nil,
      push:       false,
      code:       stack_move_to(self_class_pointer + offset, size),
    },
    get_class_ivar: {
      operands:   [offset : Int32, size : Int32],
      pop_values: [pointer : Pointer(UInt8)] of Nil,
      push:       false,
      code:       stack_move_from(pointer + offset, size),
    },
    # >>> Instance vars (3)

    # <<< Constants (1)
    get_const: {
      operands:   [index : Int32, size : Int32],
      pop_values: [] of Nil,
      push:       false,
      code:       get_const(index, size),
    },
    # >>> Constants (1)

    # <<< Class vars (1)
    get_class_var: {
      operands:   [index : Int32, size : Int32],
      pop_values: [] of Nil,
      push:       false,
      code:       get_class_var(index, size),
    },
    set_class_var: {
      operands:   [index : Int32, size : Int32],
      pop_values: [] of Nil,
      push:       false,
      code:       set_class_var(index, size),
    },
    # >>> Class vars (1)

    # <<< Stack manipulation (5)
    pop: {
      operands:   [size : Int32] of Nil,
      pop_values: [] of Nil,
      push:       false,
      code:       stack_shrink_by(size),
    },
    pop_from_offset: {
      operands:   [size : Int32, offset : Int32] of Nil,
      pop_values: [] of Nil,
      push:       false,
      code:       begin
        (stack - offset - size).move_from(stack - offset, offset)
        stack_shrink_by(size)
      end,
    },
    dup: {
      operands:   [size : Int32] of Nil,
      pop_values: [] of Nil,
      push:       false,
      code:       stack_move_from(stack - size, size),
    },
    push_zeros: {
      operands:   [amount : Int32] of Nil,
      pop_values: [] of Nil,
      push:       false,
      code:       stack_grow_by(amount),
    },
    put_stack_top_pointer: {
      operands:   [size : Int32],
      pop_values: [] of Nil,
      push:       true,
      code:       stack - size,
    },
    # >>> Stack manipulation (5)

    # <<< Jumps (3)
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
    # >>> Jumps (3)

    # <<< Pointerof (2)
    pointerof_var: {
      operands:   [index : Int32],
      pop_values: [] of Nil,
      push:       true,
      code:       get_local_var_pointer(index),
    },
    pointerof_ivar: {
      operands:   [offset : Int32],
      pop_values: [] of Nil,
      push:       true,
      code:       get_ivar_pointer(offset),
    },
    # >>> Pointerof (2)

    # <<< Calls (5)
    call: {
      operands:    [compiled_def : CompiledDef],
      pop_values:  [] of Nil,
      push:        false,
      code:        call(compiled_def),
      disassemble: {
        compiled_def: "#{compiled_def.def.name}",
      },
    },
    call_with_block: {
      operands:    [compiled_def : CompiledDef],
      pop_values:  [] of Nil,
      push:        false,
      code:        call_with_block(compiled_def),
      disassemble: {
        compiled_def: "#{compiled_def.def.name}",
      },
    },
    call_block: {
      operands:   [compiled_block : CompiledBlock],
      pop_values: [] of Nil,
      push:       false,
      code:       call_block(compiled_block),
    },
    lib_call: {
      operands:   [lib_function : LibFunction],
      pop_values: [] of Nil,
      push:       false,
      code:       lib_call(lib_function),
    },
    leave: {
      operands:   [size : Int32] of Nil,
      pop_values: [] of Nil,
      push:       false,
      code:       leave(size),
    },
    leave_def: {
      operands:   [size : Int32] of Nil,
      pop_values: [] of Nil,
      push:       false,
      code:       leave_def(size),
    },
    break_block: {
      operands:   [size : Int32] of Nil,
      pop_values: [] of Nil,
      push:       false,
      code:       break_block(size),
    },
    # >>> Calls (4)

    # <<< Allocate (2)
    allocate_class: {
      operands:   [size : Int32, type_id : Int32],
      pop_values: [] of Nil,
      push:       true,
      code:       begin
        ptr = Pointer(Void).malloc(size).as(UInt8*)
        ptr.as(Int32*).value = type_id
        ptr
      end,
    },
    # >>> Allocate (2)

    # <<< Unions (4)
    put_in_union: {
      operands:   [type_id : Int32, from_size : Int32, union_size : Int32],
      pop_values: [] of Nil,
      push:       false,
      code:       begin
        tmp_stack = stack
        stack_grow_by(union_size - from_size)
        (tmp_stack - from_size).copy_to(tmp_stack - from_size + type_id_bytesize, from_size)
        (tmp_stack - from_size).as(Int64*).value = type_id.to_i64!
      end,
      disassemble: {
        type_id: context.type_from_id(type_id),
      },
    },
    remove_from_union: {
      operands:   [union_size : Int32, from_size : Int32],
      pop_values: [] of Nil,
      push:       false,
      code:       begin
        (stack - union_size).move_from(stack - union_size + type_id_bytesize, from_size)
        stack_shrink_by(union_size - from_size)
      end,
    },
    union_is_a: {
      operands:   [union_size : Int32, filter_type_id : Int32],
      pop_values: [] of Nil,
      push:       true,
      code:       begin
        type_id = (stack - union_size).as(Int32*).value
        type = type_from_type_id(type_id)
        stack_shrink_by(union_size)

        filter_type = type_from_type_id(filter_type_id)

        !!type.filter_by(filter_type)
      end,
      disassemble: {
        filter_type_id: context.type_from_id(filter_type_id),
      },
    },
    union_to_bool: {
      operands:   [union_size : Int32],
      pop_values: [] of Nil,
      push:       true,
      code:       begin
        type_id = (stack - union_size).as(Int32*).value
        type = type_from_type_id(type_id)
        value = case type
                when NilType
                  false
                when BoolType
                  # TODO: union type id size
                  (stack - union_size + 8).as(Bool*).value
                when PointerInstanceType
                  (stack - union_size + 8).as(UInt8**).value.null?
                else
                  true
                end
        stack_shrink_by(union_size)

        value
      end,
    },
    # >>> Unions (4)

    # <<< Tuples (1)
    tuple_indexer_known_index: {
      operands:   [tuple_size : Int32, offset : Int32, value_size : Int32] of Nil,
      pop_values: [] of Nil,
      push:       false,
      code:       begin
        (stack - tuple_size).copy_from(stack - tuple_size + offset, value_size)
        aligned_value_size = align(value_size)
        stack_shrink_by(tuple_size - value_size)
        stack_grow_by(aligned_value_size - value_size)
      end,
    },
    copy_from: {
      operands:   [offset : Int32, size : Int32] of Nil,
      pop_values: [] of Nil,
      push:       false,
      code:       stack_move_from(stack - offset, size),
    },
    # >>> Tuples (1)

    # <<< Symbol (1)
    symbol_to_s: {
      operands:   [] of Nil,
      pop_values: [index : Int32] of Nil,
      push:       true,
      code:       @context.index_to_symbol(index).object_id.unsafe_as(UInt64),
    },
    # >>> Symbol (1)

    # <<< Symbol (1)
    proc_call: {
      operands:   [] of Nil,
      pop_values: [compiled_def : CompiledDef, closure_data : Pointer(Void)] of Nil,
      push:       true,
      code:       call(compiled_def),
    },
    # >>> Symbol (1)

    # <<< Overrides (6)
    repl_call_stack_unwind: {
      operands:   [] of Nil,
      pop_values: [] of Nil,
      push:       true,
      code:       begin
        # TODO: compute interpreter call stack
        Pointer(UInt8).null
      end,
    },
    repl_raise_without_backtrace: {
      operands:   [] of Nil,
      pop_values: [] of Nil,
      push:       false,
      code:       begin
        # TODO: actually raise and interpret things
        raise "An exception was raised, but the interpret doesn't know how to raise exceptions yet"
      end,
    },
    repl_intrinsics_memcpy: {
      operands:   [] of Nil,
      pop_values: [dest : Pointer(Void), src : Pointer(Void), len : UInt64, is_volatile : Bool] of Nil,
      push:       false,
      code:       begin
        # TODO: memcpy varies depending on the platform, so don't assume these are always the pop values
        # This is a pretty weird `if`, but the `memcpy` intrinsic requires the last argument to be a constant
        if is_volatile
          LibIntrinsics.memcpy(dest, src, len, true)
        else
          LibIntrinsics.memcpy(dest, src, len, false)
        end
      end,
    },
    repl_intrinsics_memmove: {
      operands:   [] of Nil,
      pop_values: [dest : Pointer(Void), src : Pointer(Void), len : UInt64, is_volatile : Bool] of Nil,
      push:       false,
      code:       begin
        # TODO: memmove varies depending on the platform, so don't assume these are always the pop values
        # This is a pretty weird `if`, but the `memmove` intrinsic requires the last argument to be a constant
        if is_volatile
          LibIntrinsics.memmove(dest, src, len, true)
        else
          LibIntrinsics.memmove(dest, src, len, false)
        end
      end,
    },
    repl_intrinsics_memset: {
      operands:   [] of Nil,
      pop_values: [dest : Pointer(Void), val : UInt8, len : UInt64, is_volatile : Bool] of Nil,
      push:       false,
      code:       begin
        # TODO: memset varies depending on the platform, so don't assume these are always the pop values
        # This is a pretty weird `if`, but the `memset` intrinsic requires the last argument to be a constant
        if is_volatile
          LibIntrinsics.memset(dest, val, len, true)
        else
          LibIntrinsics.memset(dest, val, len, false)
        end
      end,
    },
    repl_intrinsics_debugtrap: {
      operands:   [] of Nil,
      pop_values: [] of Nil,
      push:       false,
      code:       pry,
    },
    repl_proc_f32_f32: {
      operands:   [name : Symbol],
      pop_values: [a : Float32] of Nil,
      push:       true,
      code:       @context.procs_f32_f32[name].call(a),
    },
    repl_proc_f64_f64: {
      operands:   [name : Symbol],
      pop_values: [a : Float64] of Nil,
      push:       true,
      code:       @context.procs_f64_f64[name].call(a),
    },
    unreachable: {
      operands:   [] of Nil,
      pop_values: [] of Nil,
      push:       false,
      code:       raise "BUG: reached the unreachable",
    },
    # >>> Overrides (6)

  }

{% puts "Remaining opcodes: #{256 - Crystal::Repl::Instructions.size}" %}
