# CachedPowers is ported from the C++ "double-conversions" library.
# The following is their license:
#   Copyright 2006-2008 the V8 project authors. All rights reserved.
#   Redistribution and use in source and binary forms, with or without
#   modification, are permitted provided that the following conditions are
#   met:
#
#       * Redistributions of source code must retain the above copyright
#         notice, this list of conditions and the following disclaimer.
#       * Redistributions in binary form must reproduce the above
#         copyright notice, this list of conditions and the following
#         disclaimer in the documentation and/or other materials provided
#         with the distribution.
#       * Neither the name of Google Inc. nor the names of its
#         contributors may be used to endorse or promote products derived
#         from this software without specific prior written permission.
#
#   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
#   "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
#   LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
#   A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
#   OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
#   SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
#   LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
#   DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
#   THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
#   (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
#   OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

module Float::Printer::CachedPowers
  record Power, significand : UInt64, binary_exp : Int16, decimal_exp : Int16
  # The minimal and maximal target exponent define the range of w's binary
  # exponent, where 'w' is the result of multiplying the input by a cached power
  # of ten.
  #
  # A different range might be chosen on a different platform, to optimize digit
  # generation, but a smaller range requires more powers of ten to be cached.
  MIN_TARGET_EXP = -60
  MAX_TARGET_EXP = -32

  CACHED_POWER_OFFSET = 348 # -1 * the first decimal_exp

  # Not all powers of ten are cached. The decimal exponent of two neighboring
  # cached numbers will differ by `CACHED_EXP_STEP`
  CACHED_EXP_STEP =    8
  MIN_CACHED_EXP  = -348
  MAX_CACHED_EXP  =  340

  D_1_LOG2_10 = 0.30102999566398114 # 1 / lg(10)

  PowCache = [
    {0xfa8fd5a0081c0288_u64, -1220_i16, -348_i16},
    {0xbaaee17fa23ebf76_u64, -1193_i16, -340_i16},
    {0x8b16fb203055ac76_u64, -1166_i16, -332_i16},
    {0xcf42894a5dce35ea_u64, -1140_i16, -324_i16},
    {0x9a6bb0aa55653b2d_u64, -1113_i16, -316_i16},
    {0xe61acf033d1a45df_u64, -1087_i16, -308_i16},
    {0xab70fe17c79ac6ca_u64, -1060_i16, -300_i16},
    {0xff77b1fcbebcdc4f_u64, -1034_i16, -292_i16},
    {0xbe5691ef416bd60c_u64, -1007_i16, -284_i16},
    {0x8dd01fad907ffc3c_u64, -980_i16, -276_i16},
    {0xd3515c2831559a83_u64, -954_i16, -268_i16},
    {0x9d71ac8fada6c9b5_u64, -927_i16, -260_i16},
    {0xea9c227723ee8bcb_u64, -901_i16, -252_i16},
    {0xaecc49914078536d_u64, -874_i16, -244_i16},
    {0x823c12795db6ce57_u64, -847_i16, -236_i16},
    {0xc21094364dfb5637_u64, -821_i16, -228_i16},
    {0x9096ea6f3848984f_u64, -794_i16, -220_i16},
    {0xd77485cb25823ac7_u64, -768_i16, -212_i16},
    {0xa086cfcd97bf97f4_u64, -741_i16, -204_i16},
    {0xef340a98172aace5_u64, -715_i16, -196_i16},
    {0xb23867fb2a35b28e_u64, -688_i16, -188_i16},
    {0x84c8d4dfd2c63f3b_u64, -661_i16, -180_i16},
    {0xc5dd44271ad3cdba_u64, -635_i16, -172_i16},
    {0x936b9fcebb25c996_u64, -608_i16, -164_i16},
    {0xdbac6c247d62a584_u64, -582_i16, -156_i16},
    {0xa3ab66580d5fdaf6_u64, -555_i16, -148_i16},
    {0xf3e2f893dec3f126_u64, -529_i16, -140_i16},
    {0xb5b5ada8aaff80b8_u64, -502_i16, -132_i16},
    {0x87625f056c7c4a8b_u64, -475_i16, -124_i16},
    {0xc9bcff6034c13053_u64, -449_i16, -116_i16},
    {0x964e858c91ba2655_u64, -422_i16, -108_i16},
    {0xdff9772470297ebd_u64, -396_i16, -100_i16},
    {0xa6dfbd9fb8e5b88f_u64, -369_i16, -92_i16},
    {0xf8a95fcf88747d94_u64, -343_i16, -84_i16},
    {0xb94470938fa89bcf_u64, -316_i16, -76_i16},
    {0x8a08f0f8bf0f156b_u64, -289_i16, -68_i16},
    {0xcdb02555653131b6_u64, -263_i16, -60_i16},
    {0x993fe2c6d07b7fac_u64, -236_i16, -52_i16},
    {0xe45c10c42a2b3b06_u64, -210_i16, -44_i16},
    {0xaa242499697392d3_u64, -183_i16, -36_i16},
    {0xfd87b5f28300ca0e_u64, -157_i16, -28_i16},
    {0xbce5086492111aeb_u64, -130_i16, -20_i16},
    {0x8cbccc096f5088cc_u64, -103_i16, -12_i16},
    {0xd1b71758e219652c_u64, -77_i16, -4_i16},
    {0x9c40000000000000_u64, -50_i16, 4_i16},
    {0xe8d4a51000000000_u64, -24_i16, 12_i16},
    {0xad78ebc5ac620000_u64, 3_i16, 20_i16},
    {0x813f3978f8940984_u64, 30_i16, 28_i16},
    {0xc097ce7bc90715b3_u64, 56_i16, 36_i16},
    {0x8f7e32ce7bea5c70_u64, 83_i16, 44_i16},
    {0xd5d238a4abe98068_u64, 109_i16, 52_i16},
    {0x9f4f2726179a2245_u64, 136_i16, 60_i16},
    {0xed63a231d4c4fb27_u64, 162_i16, 68_i16},
    {0xb0de65388cc8ada8_u64, 189_i16, 76_i16},
    {0x83c7088e1aab65db_u64, 216_i16, 84_i16},
    {0xc45d1df942711d9a_u64, 242_i16, 92_i16},
    {0x924d692ca61be758_u64, 269_i16, 100_i16},
    {0xda01ee641a708dea_u64, 295_i16, 108_i16},
    {0xa26da3999aef774a_u64, 322_i16, 116_i16},
    {0xf209787bb47d6b85_u64, 348_i16, 124_i16},
    {0xb454e4a179dd1877_u64, 375_i16, 132_i16},
    {0x865b86925b9bc5c2_u64, 402_i16, 140_i16},
    {0xc83553c5c8965d3d_u64, 428_i16, 148_i16},
    {0x952ab45cfa97a0b3_u64, 455_i16, 156_i16},
    {0xde469fbd99a05fe3_u64, 481_i16, 164_i16},
    {0xa59bc234db398c25_u64, 508_i16, 172_i16},
    {0xf6c69a72a3989f5c_u64, 534_i16, 180_i16},
    {0xb7dcbf5354e9bece_u64, 561_i16, 188_i16},
    {0x88fcf317f22241e2_u64, 588_i16, 196_i16},
    {0xcc20ce9bd35c78a5_u64, 614_i16, 204_i16},
    {0x98165af37b2153df_u64, 641_i16, 212_i16},
    {0xe2a0b5dc971f303a_u64, 667_i16, 220_i16},
    {0xa8d9d1535ce3b396_u64, 694_i16, 228_i16},
    {0xfb9b7cd9a4a7443c_u64, 720_i16, 236_i16},
    {0xbb764c4ca7a44410_u64, 747_i16, 244_i16},
    {0x8bab8eefb6409c1a_u64, 774_i16, 252_i16},
    {0xd01fef10a657842c_u64, 800_i16, 260_i16},
    {0x9b10a4e5e9913129_u64, 827_i16, 268_i16},
    {0xe7109bfba19c0c9d_u64, 853_i16, 276_i16},
    {0xac2820d9623bf429_u64, 880_i16, 284_i16},
    {0x80444b5e7aa7cf85_u64, 907_i16, 292_i16},
    {0xbf21e44003acdd2d_u64, 933_i16, 300_i16},
    {0x8e679c2f5e44ff8f_u64, 960_i16, 308_i16},
    {0xd433179d9c8cb841_u64, 986_i16, 316_i16},
    {0x9e19db92b4e31ba9_u64, 1013_i16, 324_i16},
    {0xeb96bf6ebadf77d9_u64, 1039_i16, 332_i16},
    {0xaf87023b9bf0ee6b_u64, 1066_i16, 340_i16},
  ].map { |t| Power.new t[0], t[1], t[2] }

  Pow10Cache = {0, 1, 10, 100, 1000, 10000, 100000, 1000000, 10000000, 100000000, 1000000000}

  def self.largest_pow10(n, n_bits)
    # 1233/4096 is approximately 1/lg(10).
    #  We increment to skip over the first entry in the powers cache.
    guess = ((n_bits + 1) * 1233 >> 12) + 1

    # We don't have any guarantees that 2^number_bits <= number.<Paste>
    guess -= 1 if n < Pow10Cache[guess]

    return Pow10Cache[guess], guess
  end

  # Returns a cached power-of-ten with a binary exponent in the range
  # around *exp* (boundaries included).
  def self.get_cached_power_for_binary_exponent(exp) : {DiyFP, Int32}
    min_exp = MIN_TARGET_EXP - (exp + DiyFP::SIGNIFICAND_SIZE)
    max_exp = MAX_TARGET_EXP - (exp + DiyFP::SIGNIFICAND_SIZE)
    k = ((min_exp + DiyFP::SIGNIFICAND_SIZE - 1) * D_1_LOG2_10).ceil
    index = ((CACHED_POWER_OFFSET + k.to_i - 1) / CACHED_EXP_STEP) + 1
    pow = PowCache[index]
    _invariant min_exp <= pow.binary_exp
    _invariant pow.binary_exp <= max_exp
    return DiyFP.new(pow.significand, pow.binary_exp), pow.decimal_exp.to_i
  end

  private macro _invariant(exp, file = __FILE__, line = __LINE__)
    {% if !flag?(:release) %}
      unless {{exp}}
        raise "Assertion Failed #{{{file}}}:#{{{line}}}"
      end
    {% end %}
  end
end
