@[Link("m")] ifdef linux
lib Intrinsics
  ### To be uncommented once LLVM is updated
  # LLVM binary operations
  # fun div_i32 = "llvm.sdiv"(value1 : Int32, value2 : Int32) : Int32
  # fun div_f32 = "llvm.fdiv"(value1 : Float32, value2 : Float32) : Float32
  # fun div_f64 = "llvm.fdiv"(value1 : Float64, value2 : Float64) : Float64
  # fun rem_i32 = "llvm.srem"(value1 : Int32, value2 : Int32) : Int32
  # fun rem_f32 = "llvm.frem"(value1 : Float32, value2 : Float32) : Float32
  # fun rem_f64 = "llvm.frem"(value1 : Float64, value2 : Float64) : Float64

  # LLVM standard C library intrinsics
  fun ceil_f32 = "llvm.ceil.f32"(value : Float32) : Float32
  fun ceil_f64 = "llvm.ceil.f64"(value : Float64) : Float64
  fun copysign_f32 = "llvm.copysign.f32"(magnitude : Float32, sign : Float32) : Float32
  fun copysign_f64 = "llvm.copysign.f64"(magnitude : Float64, sign : Float64) : Float64
  fun cos_f32 = "llvm.cos.f32"(value : Float32) : Float32
  fun cos_f64 = "llvm.cos.f64"(value : Float64) : Float64
  fun exp_f32 = "llvm.exp.f32"(value : Float32) : Float32
  fun exp_f64 = "llvm.exp.f64"(value : Float64) : Float64
  fun floor_f32 = "llvm.floor.f32"(value : Float32) : Float32
  fun floor_f64 = "llvm.floor.f64"(value : Float64) : Float64
  fun log_f32 = "llvm.log.f32"(value : Float32) : Float32
  fun log_f64 = "llvm.log.f64"(value : Float64) : Float64
  fun log2_f32 = "llvm.log2.f32"(value : Float32) : Float32
  fun log2_f64 = "llvm.log2.f64"(value : Float64) : Float64
  fun log10_f32 = "llvm.log10.f32"(value : Float32) : Float32
  fun log10_f64 = "llvm.log10.f64"(value : Float64) : Float64
  ### To be uncommented once LLVM is updated
  # fun min_f32 = "llvm.minnum.f32"(value1 : Float32, value2 : Float32) : Float32
  # fun min_f64 = "llvm.minnum.f64"(value1 : Float64, value2 : Float64) : Float64
  # fun max_f32 = "llvm.maxnum.f32"(value1 : Float32, value2 : Float32) : Float32
  # fun max_f64 = "llvm.maxnum.f64"(value1 : Float64, value2 : Float64) : Float64
  fun pow_f32 = "llvm.pow.f32"(value : Float32, power : Float32) : Float32
  fun pow_f64 = "llvm.pow.f64"(value : Float64, power : Float64) : Float64
  fun powi_f32 = "llvm.powi.f32"(value : Float32, power : Int32) : Float32
  fun powi_f64 = "llvm.powi.f64"(value : Float64, power : Int32) : Float64
  fun round_f32 = "llvm.round.f32"(value : Float32) : Float32
  fun round_f64 = "llvm.round.f64"(value : Float64) : Float64
  fun sin_f32 = "llvm.sin.f32"(value : Float32) : Float32
  fun sin_f64 = "llvm.sin.f64"(value : Float64) : Float64
  fun sqrt_f32 = "llvm.sqrt.f32"(value : Float32) : Float32
  fun sqrt_f64 = "llvm.sqrt.f64"(value : Float64) : Float64
  fun trunc_f32 = "llvm.trunc.f32"(value : Float32) : Float32
  fun trunc_f64 = "llvm.trunc.f64"(value : Float64) : Float64
end
