@[Link("gmp")]
lib LibGMP
  alias Int = LibC::Int
  alias Long = LibC::Long
  alias ULong = LibC::ULong
  alias SizeT = LibC::SizeT
  alias Double = LibC::Double
  alias BitcntT = ULong

  alias IntPrimitiveSigned = Int8 | Int16 | Int32 | LibC::Long
  alias IntPrimitiveUnsigned = UInt8 | UInt16 | UInt32 | LibC::ULong
  alias IntPrimitive = IntPrimitiveSigned | IntPrimitiveUnsigned

  {% if flag?(:x86_64) || flag?(:aarch64) %}
    alias MpExp = Int64
  {% else %}
    alias MpExp = Int32
  {% end %}

  struct MPZ
    _mp_alloc : Int32
    _mp_size : Int32
    _mp_d : ULong*
  end

  # # Initialization

  fun init = __gmpz_init(x : MPZ*)
  fun init2 = __gmpz_init2(x : MPZ*, bits : BitcntT)
  fun init_set_ui = __gmpz_init_set_ui(rop : MPZ*, op : ULong)
  fun init_set_si = __gmpz_init_set_si(rop : MPZ*, op : Long)
  fun init_set_d = __gmpz_init_set_d(rop : MPZ*, op : Double)
  fun init_set_str = __gmpz_init_set_str(rop : MPZ*, str : UInt8*, base : Int) : Int

  # # I/O

  fun set_ui = __gmpz_set_ui(rop : MPZ*, op : ULong)
  fun set_si = __gmpz_set_si(rop : MPZ*, op : Long)
  fun set_d = __gmpz_set_d(rop : MPZ*, op : Double)
  fun set_str = __gmpz_set_str(rop : MPZ*, str : UInt8*, base : Int) : Int
  fun get_str = __gmpz_get_str(str : UInt8*, base : Int, op : MPZ*) : UInt8*
  fun get_si = __gmpz_get_si(op : MPZ*) : Long
  fun get_ui = __gmpz_get_ui(op : MPZ*) : ULong
  fun get_d = __gmpz_get_d(op : MPZ*) : Double

  # # Arithmetic

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

  fun tdiv_q = __gmpz_tdiv_q(rop : MPZ*, op1 : MPZ*, op2 : MPZ*)
  fun tdiv_q_ui = __gmpz_tdiv_q_ui(rop : MPZ*, op1 : MPZ*, op2 : ULong)

  fun fdiv_r = __gmpz_fdiv_r(rop : MPZ*, op1 : MPZ*, op2 : MPZ*)
  fun fdiv_r_ui = __gmpz_fdiv_r_ui(rop : MPZ*, op1 : MPZ*, op2 : ULong)

  fun fdiv_qr = __gmpz_fdiv_qr(q : MPZ*, r : MPZ*, n : MPZ*, d : MPZ*)
  fun fdiv_qr_ui = __gmpz_fdiv_qr_ui(q : MPZ*, r : MPZ*, n : MPZ*, d : ULong) : ULong

  fun tdiv_r = __gmpz_tdiv_r(rop : MPZ*, op1 : MPZ*, op2 : MPZ*)
  fun tdiv_r_ui = __gmpz_tdiv_r_ui(rop : MPZ*, op1 : MPZ*, op2 : ULong)
  fun tdiv_ui = __gmpz_tdiv_ui(op1 : MPZ*, op2 : ULong) : ULong

  fun tdiv_qr = __gmpz_tdiv_qr(q : MPZ*, r : MPZ*, n : MPZ*, d : MPZ*)
  fun tdiv_qr_ui = __gmpz_tdiv_qr_ui(q : MPZ*, r : MPZ*, n : MPZ*, d : ULong) : ULong

  fun neg = __gmpz_neg(rop : MPZ*, op : MPZ*)
  fun abs = __gmpz_abs(rop : MPZ*, op : MPZ*)

  fun pow_ui = __gmpz_pow_ui(rop : MPZ*, base : MPZ*, exp : ULong)

  # # Bitwise operations

  fun and = __gmpz_and(rop : MPZ*, op1 : MPZ*, op2 : MPZ*)
  fun ior = __gmpz_ior(rop : MPZ*, op1 : MPZ*, op2 : MPZ*)
  fun xor = __gmpz_xor(rop : MPZ*, op1 : MPZ*, op2 : MPZ*)
  fun com = __gmpz_com(rop : MPZ*, op : MPZ*)

  fun fdiv_q_2exp = __gmpz_fdiv_q_2exp(q : MPZ*, n : MPZ*, b : BitcntT)
  fun mul_2exp = __gmpz_mul_2exp(rop : MPZ*, op1 : MPZ*, op2 : BitcntT)

  # # Logic

  fun popcount = __gmpz_popcount(op : MPZ*) : BitcntT

  # # Comparison

  fun cmp = __gmpz_cmp(op1 : MPZ*, op2 : MPZ*) : Int
  fun cmp_si = __gmpz_cmp_si(op1 : MPZ*, op2 : Long) : Int
  fun cmp_ui = __gmpz_cmp_ui(op1 : MPZ*, op2 : ULong) : Int
  fun cmp_d = __gmpz_cmp_d(op1 : MPZ*, op2 : Double) : Int

  # # Conversion
  fun get_d_2exp = __gmpz_get_d_2exp(exp : Long*, op : MPZ*) : Double

  # # Number Theoretic Functions

  fun gcd = __gmpz_gcd(rop : MPZ*, op1 : MPZ*, op2 : MPZ*)
  fun gcd_ui = __gmpz_gcd_ui(rop : MPZ*, op1 : MPZ*, op2 : ULong) : ULong
  fun lcm = __gmpz_lcm(rop : MPZ*, op1 : MPZ*, op2 : MPZ*)
  fun lcm_ui = __gmpz_lcm_ui(rop : MPZ*, op1 : MPZ*, op2 : ULong)

  # MPQ
  struct MPQ
    _mp_num : MPZ
    _mp_den : MPZ
  end

  # # Initialization
  fun mpq_init = __gmpq_init(x : MPQ*)
  fun mpq_set_num = __gmpq_set_num(x : MPQ*, num : MPZ*)
  fun mpq_set_den = __gmpq_set_den(x : MPQ*, den : MPZ*)
  fun mpq_get_num = __gmpq_get_num(rop : MPZ*, op : MPQ*)
  fun mpq_get_den = __gmpq_get_den(rop : MPZ*, op : MPQ*)
  fun mpq_canonicalize = __gmpq_canonicalize(x : MPQ*)

  # # Conversion
  fun mpq_get_str = __gmpq_get_str(str : UInt8*, base : Int, op : MPQ*) : UInt8*
  fun mpq_get_d = __gmpq_get_d(x : MPQ*) : Float64

  # # Compare
  fun mpq_cmp = __gmpq_cmp(x : MPQ*, o : MPQ*) : Int32

  # # Arithmetic
  fun mpq_add = __gmpq_add(rop : MPQ*, op1 : MPQ*, op2 : MPQ*)
  fun mpq_sub = __gmpq_sub(rop : MPQ*, op1 : MPQ*, op2 : MPQ*)
  fun mpq_mul = __gmpq_mul(rop : MPQ*, op1 : MPQ*, op2 : MPQ*)
  fun mpq_div = __gmpq_div(rop : MPQ*, op1 : MPQ*, op2 : MPQ*)
  fun mpq_inv = __gmpq_inv(rop : MPQ*, op1 : MPQ*)
  fun mpq_neg = __gmpq_neg(rop : MPQ*, op1 : MPQ*)
  fun mpq_abs = __gmpq_abs(rop : MPQ*, op1 : MPQ*)

  fun mpq_div_2exp = __gmpq_div_2exp(q : MPQ*, n : MPQ*, b : BitcntT)
  fun mpq_mul_2exp = __gmpq_mul_2exp(rop : MPQ*, op1 : MPQ*, op2 : BitcntT)

  # MPF
  struct MPF
    _mp_prec : Int
    _mp_size : Int
    _mp_exp : MpExp
    _mp_d : ULong*
  end

  # # Initialization
  fun mpf_init = __gmpf_init(x : MPF*)
  fun mpf_init2 = __gmpf_init2(x : MPF*, prec : BitcntT)
  fun mpf_init_set_d = __gmpf_init_set_d(rop : MPF*, op : Double)
  fun mpf_init_set_str = __gmpf_init_set_str(rop : MPF*, str : UInt8*, base : Int) : Int
  fun mpf_init_set_ui = __gmpf_init_set_ui(rop : MPF*, op : ULong)
  fun mpf_init_set_si = __gmpf_init_set_si(rop : MPF*, op : Long)

  # # Precision
  fun mpf_set_default_prec = __gmpf_set_default_prec(prec : BitcntT)
  fun mpf_get_default_prec = __gmpf_get_default_prec : BitcntT

  # # Conversion
  fun mpf_get_str = __gmpf_get_str(str : UInt8*, expptr : MpExp*, base : Int, n_digits : LibC::SizeT, op : MPF*) : UInt8*
  fun mpf_get_d = __gmpf_get_d(op : MPF*) : Double
  fun mpf_set_d = __gmpf_set_d(op : MPF*, op : Double)
  fun mpf_set = __gmpf_set(op : MPF*, op : MPF*)
  fun mpf_set_z = __gmpf_set_z(rop : MPF*, op : MPZ*)
  fun mpf_set_q = __gmpf_set_q(rop : MPF*, op : MPQ*)
  fun mpf_get_si = __gmpf_get_si(op : MPF*) : Long
  fun mpf_get_ui = __gmpf_get_ui(op : MPF*) : ULong
  fun mpf_get_d_2exp = __gmpf_get_d_2exp(exp : Long*, op : MPF*) : Double

  # # Arithmetic
  fun mpf_add = __gmpf_add(rop : MPF*, op1 : MPF*, op2 : MPF*)
  fun mpf_sub = __gmpf_sub(rop : MPF*, op1 : MPF*, op2 : MPF*)
  fun mpf_mul = __gmpf_mul(rop : MPF*, op1 : MPF*, op2 : MPF*)
  fun mpf_div = __gmpf_div(rop : MPF*, op1 : MPF*, op2 : MPF*)
  fun mpf_div_ui = __gmpf_div_ui(rop : MPF*, op1 : MPF*, op2 : ULong)
  fun mpf_neg = __gmpf_neg(rop : MPF*, op : MPF*)
  fun mpf_abs = __gmpf_abs(rop : MPF*, op : MPF*)
  fun mpf_sqrt = __gmpf_sqrt(rop : MPF*, op : MPF*)
  fun mpf_pow_ui = __gmpf_pow_ui(rop : MPF*, op1 : MPF*, op2 : ULong)
  fun mpf_mul_2exp = __gmpf_mul_2exp(rop : MPF*, op1 : MPF*, op2 : BitcntT)
  fun mpf_div_2exp = __gmpf_div_2exp(rop : MPF*, op1 : MPF*, op2 : BitcntT)

  # # Comparison
  fun mpf_cmp = __gmpf_cmp(op1 : MPF*, op2 : MPF*) : Int
  fun mpf_cmp_d = __gmpf_cmp_d(op1 : MPF*, op2 : Double) : Int
  fun mpf_cmp_ui = __gmpf_cmp_ui(op1 : MPF*, op2 : ULong) : Int
  fun mpf_cmp_si = __gmpf_cmp_si(op1 : MPF*, op2 : Long) : Int
  fun mpf_cmp_z = __gmpf_cmp_z(op1 : MPF*, op2 : MPZ*) : Int

  # # Miscellaneous
  fun mpf_ceil = __gmpf_ceil(rop : MPF*, op : MPF*)
  fun mpf_floor = __gmpf_floor(rop : MPF*, op : MPF*)
  fun mpf_trunc = __gmpf_trunc(rop : MPF*, op : MPF*)
  fun mpf_integer_p = __gmpf_integer_p(op : MPF*) : Int

  # # Memory

  fun set_memory_functions = __gmp_set_memory_functions(malloc : SizeT -> Void*, realloc : Void*, SizeT, SizeT -> Void*, free : Void*, SizeT ->)
end

LibGMP.set_memory_functions(
  ->(size) { GC.malloc(size) },
  ->(ptr, old_size, new_size) { GC.realloc(ptr, new_size) },
  ->(ptr, size) { GC.free(ptr) }
)
