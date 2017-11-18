# :nodoc: Forward declarations
struct BigInt < Int
end

struct BigFloat < Float
end

struct BigRational < Number
end

struct BigDecimal < Number
end

require "./big/lib_gmp"
require "./big/big_int"
require "./big/big_float"
require "./big/big_rational"
require "./big/big_decimal"
