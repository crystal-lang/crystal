@[Link("gmp")]
lib LibGMP
  alias Int = LibC::Int
  alias Long = LibC::Long
  alias ULong = LibC::ULong
  alias SizeT = LibC::SizeT
  alias Double = LibC::Double
  alias BitcntT = ULong

  struct MPZ
    _mp_alloc : Int32
    _mp_size  : Int32
    _mp_d     : ULong*
  end

  ## Initialization

  fun init = __gmpz_init(x : MPZ*)
  fun init2 = __gmpz_init2(x : MPZ*, bits : BitcntT)
  fun init_set_ui = __gmpz_init_set_ui(rop : MPZ*, op : ULong)
  fun init_set_si = __gmpz_init_set_si(rop : MPZ*, op : Long)
  fun init_set_d = __gmpz_init_set_d(rop : MPZ*, op : Double)
  fun init_set_str = __gmpz_init_set_str(rop : MPZ*, str : UInt8*, base : Int)

  ## I/O

  fun set_ui = __gmpz_set_ui(rop : MPZ*, op : ULong)
  fun set_si = __gmpz_set_si(rop : MPZ*, op : Long)
  fun set_d = __gmpz_set_d(rop : MPZ*, op : Double)
  fun set_str = __gmpz_set_str(rop : MPZ*, str : UInt8*, base : Int) : Int
  fun get_str = __gmpz_get_str(str : UInt8*, base : Int, op : MPZ*) : UInt8*
  fun get_si = __gmpz_get_si(op : MPZ*) : Long
  fun get_d = __gmpz_get_d(op : MPZ*) : Double

  ## Arithmetic

  fun add = __gmpz_add(rop : MPZ*, op1 : MPZ*, op2 : MPZ*)
  fun add_ui = __gmpz_add_ui(rop : MPZ*, op1 : MPZ*, op2 : ULong)

  fun sub = __gmpz_sub(rop : MPZ*, op1 : MPZ*, op2 : MPZ*)
  fun sub_ui = __gmpz_sub_ui(rop : MPZ*, op1 : MPZ*, op2 : ULong)
  fun ui_sub = __gmpz_ui_sub(rop : MPZ*, op1 : ULong, op2 : MPZ*)

  fun mul = __gmpz_mul(rop : MPZ*, op1 : MPZ*, op2 : MPZ*)
  fun mul_si = __gmpz_mul_si(rop : MPZ*, op1 : MPZ*, op2 : Long)
  fun mul_ui = __gmpz_mul_ui(rop : MPZ*, op1 : MPZ*, op2 : ULong)

  fun fdiv_q = __gmpz_fdiv_q(rop : MPZ*, op1 : MPZ*, op2 : MPZ*)
  fun fdiv_q_ui = __gmpz_fdiv_q_ui(rop : MPZ*, op1 : MPZ*, op2 : ULong)

  fun fdiv_r = __gmpz_fdiv_r(rop : MPZ*, op1 : MPZ*, op2 : MPZ*)
  fun fdiv_r_ui = __gmpz_fdiv_r_ui(rop : MPZ*, op1 : MPZ*, op2 : ULong)

  fun neg = __gmpz_neg(rop : MPZ*, op : MPZ*)
  fun abs = __gmpz_abs(rop : MPZ*, op : MPZ*)

  fun pow_ui = __gmpz_pow_ui(rop : MPZ*, base : MPZ*, exp : ULong)

  ## Bitwise operations

  fun and = __gmpz_and(rop : MPZ*, op1 : MPZ*, op2 : MPZ*)
  fun ior = __gmpz_ior(rop : MPZ*, op1 : MPZ*, op2 : MPZ*)
  fun xor = __gmpz_xor(rop : MPZ*, op1 : MPZ*, op2 : MPZ*)
  fun com = __gmpz_com(rop : MPZ*, op : MPZ*)

  fun fdiv_q_2exp = __gmpz_fdiv_q_2exp(q : MPZ*, n : MPZ*, b : BitcntT)
  fun mul_2exp = __gmpz_mul_2exp(rop : MPZ*, op1 : MPZ*, op2 : BitcntT)

  ## Comparison

  fun cmp = __gmpz_cmp(op1 : MPZ*, op2 : MPZ*) : Int
  fun cmp_si = __gmpz_cmp_si(op1 : MPZ*, op2 : Long) : Int
  fun cmp_ui = __gmpz_cmp_ui(op1 : MPZ*, op2 : ULong) : Int

  ## Memory

  fun set_memory_functions = __gmp_set_memory_functions(malloc : SizeT -> Void*, realloc : Void*, SizeT, SizeT -> Void*, free : Void*, SizeT ->)
end

LibGMP.set_memory_functions(
  ->(size) { GC.malloc(size) },
  ->(ptr, old_size, new_size) { GC.realloc(ptr, new_size) },
  ->(ptr, size) { GC.free(ptr) }
  )

