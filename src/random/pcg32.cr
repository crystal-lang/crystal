# This is a Crystal conversion of basic C PCG implementation
#
#  Original file notice:
#
#  PCG Random Number Generation for C.
#
#  Copyright 2014 Melissa O'Neill <oneill@pcg-random.org>
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#
#  For additional information about the PCG random number generation scheme,
#  including its license and other licensing options, visit
#
#        http://www.pcg-random.org
#

# pcg32_random_r:
#       -  result:      32-bit unsigned int (uint32_t)
#       -  period:      2^64   (* 2^63 streams)
#       -  state type:  pcg32_random_t (16 bytes)
#       -  output func: XSH-RR
class Random::PCG32
  include Random

  PCG_DEFAULT_MULTIPLIER_64 = 6364136223846793005_u64

  @state : UInt64
  @inc : UInt64

  def initialize(initstate = UInt64.new(Random.new_seed), initseq = 0_u64)
    # initialize to zeros to prevent compiler complains
    @state = 0_u64
    @inc = 0_u64
    new_seed(initstate, initseq)
  end

  def new_seed(initstate = UInt64.new(Random.new_seed), initseq = 0_u64)
    @state = 0_u64
    @inc = (initseq << 1) | 1
    next_u
    @state += initstate
    next_u
  end

  def next_u
    oldstate = @state
    @state = oldstate * PCG_DEFAULT_MULTIPLIER_64 + @inc
    xorshifted = UInt32.new(((oldstate >> 18) ^ oldstate) >> 27)
    rot = UInt32.new(oldstate >> 59)
    return UInt32.new((xorshifted >> rot) | (xorshifted << ((~rot + 1) & 31)))
  end

  def jump(delta)
    deltau64 = UInt64.new(delta)
    acc_mult = 1u64
    acc_plus = 0u64
    cur_plus = @inc
    cur_mult = PCG_DEFAULT_MULTIPLIER_64
    while (deltau64 > 0)
      if deltau64 & 1 > 0
        acc_mult *= cur_mult
        acc_plus = acc_plus * cur_mult + cur_plus
      end
      cur_plus = (cur_mult + 1) * cur_plus
      cur_mult *= cur_mult
      deltau64 /= 2
    end
    @state = acc_mult * @state + acc_plus
  end
end
