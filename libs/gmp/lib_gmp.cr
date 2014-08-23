lib LibGMP("gmp")
  struct MPZ
    _mp_alloc : Int32
    _mp_size  : Int32
    _mp_d     : UInt64*
  end

  ## Initialization

  fun init = __gmpz_init(x : MPZ*)
  fun init2 = __gmpz_init2(x : MPZ*, bits : UInt64)
  fun init_set_ui = __gmpz_init_set_ui(rop : MPZ*, op : UInt64)
  fun init_set_si = __gmpz_init_set_si(rop : MPZ*, op : Int64)
  fun init_set_str = __gmpz_init_set_str(rop : MPZ*, str : UInt8*, base : Int32)

  ## I/O

  fun set_ui = __gmpz_set_ui(rop : MPZ*, op : UInt64)
  fun set_si = __gmpz_set_si(rop : MPZ*, op : Int64)
  fun set_str = __gmpz_set_str(rop : MPZ*, str : UInt8*, base : Int32) : Int32
  fun get_str = __gmpz_get_str(str : UInt8*, base : Int32, op : MPZ*) : UInt8*

  ## Arithmetic

  fun add = __gmpz_add(rop : MPZ*, op1 : MPZ*, op2 : MPZ*)
  fun add_ui = __gmpz_add_ui(rop : MPZ*, op1 : MPZ*, op2 : UInt64)

  fun sub = __gmpz_sub(rop : MPZ*, op1 : MPZ*, op2 : MPZ*)
  fun sub_ui = __gmpz_sub_ui(rop : MPZ*, op1 : MPZ*, op2 : UInt64)
  fun ui_sub = __gmpz_ui_sub(rop : MPZ*, op1 : UInt64, op2 : MPZ*)

  fun mul = __gmpz_mul(rop : MPZ*, op1 : MPZ*, op2 : MPZ*)
  fun mul_si = __gmpz_mul_si(rop : MPZ*, op1 : MPZ*, op2 : Int64) # TODO: op2 : long int
  fun mul_ui = __gmpz_mul_ui(rop : MPZ*, op1 : MPZ*, op2 : UInt64) # TODO: op2 : unsigned long int

  fun fdiv_q = __gmpz_fdiv_q(rop : MPZ*, op1 : MPZ*, op2 : MPZ*)
  fun fdiv_q_ui = __gmpz_fdiv_q_ui(rop : MPZ*, op1 : MPZ*, op2 : UInt64)

  fun fdiv_r = __gmpz_fdiv_r(rop : MPZ*, op1 : MPZ*, op2 : MPZ*)
  fun fdiv_r_ui = __gmpz_fdiv_r_ui(rop : MPZ*, op1 : MPZ*, op2 : UInt64)

  fun neg = __gmpz_neg(rop : MPZ*, op : MPZ*)
  fun abs = __gmpz_abs(rop : MPZ*, op : MPZ*)

  ## Comparison

  fun cmp = __gmpz_cmp(op1 : MPZ*, op2 : MPZ*) : Int32
  fun cmp_si = __gmpz_cmp_si(op1 : MPZ*, op2 : Int64) : Int32
  fun cmp_ui = __gmpz_cmp_ui(op1 : MPZ*, op2 : UInt64) : Int32

  ## Memory

  fun set_memory_functions = __gmp_set_memory_functions(malloc : C::SizeT -> Void*, realloc : Void*, C::SizeT, C::SizeT -> Void*, free : Void*, C::SizeT ->)
end

LibGMP.set_memory_functions(
  ->(size) { GC.malloc(size.to_u32) },
  ->(ptr, old_size, new_size) { GC.realloc(ptr, new_size.to_u32) },
  ->(ptr, size) { GC.free(ptr) }
  )

