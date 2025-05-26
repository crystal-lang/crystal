require "spec"

# Exhaustively checks that for all 4294967296 possible `Float32` values,
# `to_s.to_f32` returns the original number. Splits the floats into 4096 bins
# for better progress tracking. Also useful as a sort of benchmark.
#
# This was originally added when `String#to_f` moved from `LibC.strtod` to
# `fast_float`, but is applicable to any other implementation as well.
describe "x.to_s.to_f32 == x" do
  (0_u32..0xFFF_u32).each do |i|
    it "%03x00000..%03xfffff" % {i, i} do
      0x100000.times do |j|
        bits = i << 20 | j
        float = bits.unsafe_as(Float32)
        str = float.to_s
        val = str.to_f32?.should_not be_nil

        if float.nan?
          val.nan?.should be_true
        else
          val.should eq(float)
          val.sign_bit.should eq(float.sign_bit)
        end
      end
    end
  end
end
