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
    mul_i32: {
      operands:   [] of Nil,
      pop_values: [a : Int32, b : Int32],
      push:       true,
      code:       a * b,
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
    mul_i64: {
      operands:   [] of Nil,
      pop_values: [a : Int64, b : Int64],
      push:       true,
      code:       a * b,
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
    eq_i32: {
      operands:   [] of Nil,
      pop_values: [a : Int32, b : Int32],
      push:       true,
      code:       a == b,
    },
    neq_i32: {
      operands:   [] of Nil,
      pop_values: [a : Int32, b : Int32],
      push:       true,
      code:       a != b,
    },
    lt_i32: {
      operands:   [] of Nil,
      pop_values: [a : Int32, b : Int32],
      push:       true,
      code:       a < b,
    },
    le_i32: {
      operands:   [] of Nil,
      pop_values: [a : Int32, b : Int32],
      push:       true,
      code:       a <= b,
    },
    gt_i32: {
      operands:   [] of Nil,
      pop_values: [a : Int32, b : Int32],
      push:       true,
      code:       a > b,
    },
    ge_i32: {
      operands:   [] of Nil,
      pop_values: [a : Int32, b : Int32],
      push:       true,
      code:       a >= b,
    },
    eq_i64: {
      operands:   [] of Nil,
      pop_values: [a : Int64, b : Int64],
      push:       true,
      code:       a == b,
    },
    neq_i64: {
      operands:   [] of Nil,
      pop_values: [a : Int64, b : Int64],
      push:       true,
      code:       a != b,
    },
    lt_i64: {
      operands:   [] of Nil,
      pop_values: [a : Int64, b : Int64],
      push:       true,
      code:       a < b,
    },
    le_i64: {
      operands:   [] of Nil,
      pop_values: [a : Int64, b : Int64],
      push:       true,
      code:       a <= b,
    },
    gt_i64: {
      operands:   [] of Nil,
      pop_values: [a : Int64, b : Int64],
      push:       true,
      code:       a > b,
    },
    ge_i64: {
      operands:   [] of Nil,
      pop_values: [a : Int64, b : Int64],
      push:       true,
      code:       a >= b,
    },
    lt_u64: {
      operands:   [] of Nil,
      pop_values: [a : UInt64, b : UInt64],
      push:       true,
      code:       a < b,
    },
    le_u64: {
      operands:   [] of Nil,
      pop_values: [a : UInt64, b : UInt64],
      push:       true,
      code:       a <= b,
    },
    gt_u64: {
      operands:   [] of Nil,
      pop_values: [a : UInt64, b : UInt64],
      push:       true,
      code:       a > b,
    },
    ge_u64: {
      operands:   [] of Nil,
      pop_values: [a : UInt64, b : UInt64],
      push:       true,
      code:       a >= b,
    },
    lt_f64: {
      operands:   [] of Nil,
      pop_values: [a : Float64, b : Float64],
      push:       true,
      code:       a < b,
    },
    le_f64: {
      operands:   [] of Nil,
      pop_values: [a : Float64, b : Float64],
      push:       true,
      code:       a <= b,
    },
    gt_f64: {
      operands:   [] of Nil,
      pop_values: [a : Float64, b : Float64],
      push:       true,
      code:       a > b,
    },
    ge_f64: {
      operands:   [] of Nil,
      pop_values: [a : Float64, b : Float64],
      push:       true,
      code:       a >= b,
    },
    eq_f64: {
      operands:   [] of Nil,
      pop_values: [a : Float64, b : Float64],
      push:       true,
      code:       a == b,
    },
    neq_f64: {
      operands:   [] of Nil,
      pop_values: [a : Float64, b : Float64],
      push:       true,
      code:       a != b,
    },
    div_f64: {
      operands:   [] of Nil,
      pop_values: [a : Float64, b : Float64],
      push:       true,
      code:       a / b,
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
      code:       begin
        ptr = Pointer(UInt8).malloc(size * element_size)
        # p! ptr, size, element_size
        ptr
      end,
    },
    pointer_realloc: {
      operands:   [element_size : Int32] of Nil,
      pop_values: [pointer : Pointer(UInt8), size : UInt64],
      push:       true,
      code:       begin
        # p! pointer, size, element_size
        pointer.realloc(size * element_size)
      end,
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
      code:       stack_shrink_by(size),
    },
    pop_from_offset: {
      operands:   [size : Int32, offset : Int32] of Nil,
      pop_values: [] of Nil,
      push:       false,
      code:       begin
        stack_shrink_by(offset + size)
        stack_move_from(stack + size, offset)
      end,
    },
    dup: {
      operands:   [size : Int32] of Nil,
      pop_values: [] of Nil,
      push:       false,
      code:       stack_move_from(stack - size, size),
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
    pointerof_ivar: {
      operands:   [offset : Int32],
      pop_values: [] of Nil,
      push:       true,
      code:       get_ivar_pointer(offset),
    },
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
    allocate_class: {
      operands:   [size : Int32, type_id : Int32],
      pop_values: [] of Nil,
      push:       true,
      code:       begin
        ptr = Pointer(UInt8).malloc(size)
        ptr.as(Int32*).value = type_id
        ptr
      end,
    },
    allocate_struct: {
      operands:   [size : Int32],
      pop_values: [] of Nil,
      push:       false,
      code:       begin
        stack.clear(size)
        stack_grow_by(size)
      end,
    },
    put_stack_top_pointer: {
      operands:   [size : Int32],
      pop_values: [] of Nil,
      push:       true,
      code:       stack - size,
    },
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
    put_in_union: {
      operands:   [type_id : Int32, from_size : Int32, union_size : Int32],
      pop_values: [] of Nil,
      push:       false,
      code:       begin
        (stack - from_size).copy_to(stack - from_size + type_id_bytesize, from_size)
        (stack - from_size).as(Int64*).value = type_id.to_i64!
        stack_grow_by(union_size - from_size)
      end,
    },
    remove_from_union: {
      operands:   [union_size : Int32, from_size : Int32],
      pop_values: [] of Nil,
      push:       false,
      code:       begin
        # TODO: clean up stack
        stack_shrink_by(union_size)
        stack_move_from(stack + type_id_bytesize, from_size)
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
    },
    union_to_bool: {
      operands:   [union_size : Int32],
      pop_values: [] of Nil,
      push:       true,
      code:       begin
        # TODO: clean up stack
        stack_shrink_by(union_size)
        type_id = stack.as(Int32*).value
        type = type_from_type_id(type_id)
        case type
        when NilType
          false
        when BoolType
          # TODO: union type id size
          (stack + 8).as(Bool*).value
        when PointerInstanceType
          (stack + 8).as(UInt8**).value.null?
        else
          true
        end
      end,
    },
    pointer_is_not_null: {
      operands:   [] of Nil,
      pop_values: [pointer : Pointer(UInt8)],
      push:       true,
      code:       !pointer.null?,
    },
    tuple_indexer_known_index: {
      operands:   [tuple_size : Int32, offset : Int32, value_size : Int32] of Nil,
      pop_values: [] of Nil,
      push:       false,
      code:       begin
        # TODO: clean up stack
        stack_shrink_by(tuple_size)
        stack_move_from(stack + offset, value_size)
      end,
    },
    push_zeros: {
      operands:   [amount : Int32] of Nil,
      pop_values: [] of Nil,
      push:       false,
      code:       begin
        # TODO: acutally put zeros
        stack_grow_by(amount)
      end,
    },
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
    leave: {
      operands:   [size : Int32] of Nil,
      pop_values: [] of Nil,
      push:       false,
      code:       leave(size),
    },
  }

{% puts "Remaining opcodes: #{256 - Crystal::Repl::Instructions.size}" %}
