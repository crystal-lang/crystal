require "spec"

describe "Math" do
  describe "Mathematical constants" do
    it "E" do
      Math::E.should be_close(2.718281828459045, 1e-7)
    end

    it "LOG2" do
      Math::LOG2.should be_close(0.6931471805599453, 1e-7)
    end

    it "LOG10" do
      Math::LOG10.should be_close(2.302585092994046, 1e-7)
    end
  end

  describe "Functions manipulating signs" do
    it "copysign" do
      Math.copysign(6.9, -0.2).should eq(-6.9)
    end
  end

  describe "Order-related functions" do
    it { Math.min(2.1, 2.11).should eq(2.1) }
    it { Math.max(3.2, 3.11).should eq(3.2) }
  end

  pending "Functions for computing quotient and remainder" do
  end

  describe "Roots" do
    it "cbrt" do
      Math.cbrt(6.5_f32).should be_close(1.866255578408624, 1e-7)
      Math.cbrt(6.5).should be_close(1.866255578408624, 1e-7)
    end

    it "sqrt" do
      Math.sqrt(5.2_f32).should be_close(2.280350850198276, 1e-7)
      Math.sqrt(5.2).should be_close(2.280350850198276, 1e-7)
      Math.sqrt(4_f32).should eq(2)
      Math.sqrt(4).should eq(2)
    end

    it "isqrt" do
      Math.isqrt(9).should eq(3)
      Math.isqrt(8).should eq(2)
      Math.isqrt(4).should eq(2)
      {% for type in [UInt8, UInt16, UInt32, UInt64, UInt128, Int8, Int16, Int32, Int64, Int128] %}
        %val = {{ type }}.new 42
        %exp = {{ type }}.new 6
        Math.isqrt(%val).should eq(%exp)
      {% end %}
    end
  end

  describe "Exponents" do
    it "exp" do
      Math.exp(0.211_f32).should be_close(1.2349123550613943, 1e-7)
      Math.exp(0.211).should be_close(1.2349123550613943, 1e-7)
    end

    it "exp2" do
      Math.exp2(0.41_f32).should be_close(1.3286858140965117, 1e-7)
      Math.exp2(0.41).should be_close(1.3286858140965117, 1e-7)
    end

    it "expm1" do
      Math.expm1(0.99_f32).should be_close(1.6912344723492623, 1e-6)
      Math.expm1(0.99).should be_close(1.6912344723492623, 1e-7)
    end

    it "ilogb" do
      Math.ilogb(0.5_f32).should eq(-1)
      Math.ilogb(0.5).should eq(-1)
    end

    it "ldexp" do
      Math.ldexp(0.27_f32, 2).should be_close(1.08, 1e-7)
      Math.ldexp(0.27, 2).should be_close(1.08, 1e-7)
    end

    it "logb" do
      Math.logb(10_f32).should be_close(3.0, 1e-7)
      Math.logb(10.0).should be_close(3.0, 1e-7)
    end

    it "scalbn" do
      Math.scalbn(0.2_f32, 3).should be_close(1.6, 1e-7)
      Math.scalbn(0.2, 3).should be_close(1.6, 1e-7)
    end

    it "scalbln" do
      Math.scalbln(0.11_f32, 2).should be_close(0.44, 1e-7)
      Math.scalbln(0.11, 2).should be_close(0.44, 1e-7)
    end

    it "frexp" do
      Math.frexp(0.2_f32).should eq({0.8_f32, -2})
      Math.frexp(0.2).should eq({0.8, -2})
    end
  end

  describe "Logarithms" do
    it "log" do
      Math.log(3.24_f32).should be_close(1.1755733298042381, 1e-7)
      Math.log(3.24).should be_close(1.1755733298042381, 1e-7)
      Math.log(0.3_f32, 3).should be_close(-1.0959032742893848, 1e-7)
      Math.log(0.3, 3).should be_close(-1.0959032742893848, 1e-7)
    end

    it "log2" do
      Math.log2(1.2_f32).should be_close(0.2630344058337938, 1e-7)
      Math.log2(1.2).should be_close(0.2630344058337938, 1e-7)
    end

    it "log10" do
      Math.log10(0.5_f32).should be_close(-0.3010299956639812, 1e-7)
      Math.log10(0.5).should be_close(-0.3010299956639812, 1e-7)
    end

    it "log1p" do
      Math.log1p(0.67_f32).should be_close(0.5128236264286637, 1e-7)
      Math.log1p(0.67).should be_close(0.5128236264286637, 1e-7)
    end
  end

  describe "Trigonometric functions" do
    it "cos" do
      Math.cos(2.23_f32).should be_close(-0.6124875656583851, 1e-7)
      Math.cos(2.23).should be_close(-0.6124875656583851, 1e-7)
    end

    it "sin" do
      Math.sin(3.3_f32).should be_close(-0.1577456941432482, 1e-7)
      Math.sin(3.3).should be_close(-0.1577456941432482, 1e-7)
    end

    it "tan" do
      Math.tan(0.91_f32).should be_close(1.2863693807208076, 1e-7)
      Math.tan(0.91).should be_close(1.2863693807208076, 1e-7)
    end

    it "hypot" do
      Math.hypot(2.1_f32, 1.5_f32).should be_close(2.5806975801127883, 1e-7)
      Math.hypot(2.1, 1.5).should be_close(2.5806975801127883, 1e-7)
    end
  end

  describe "Inverse trigonometric functions" do
    it "acos" do
      Math.acos(0.125_f32).should be_close(1.445468495626831, 1e-7)
      Math.acos(0.125).should be_close(1.445468495626831, 1e-7)
    end

    it "asin" do
      Math.asin(-0.4_f32).should be_close(-0.41151684606748806, 1e-7)
      Math.asin(-0.4).should be_close(-0.41151684606748806, 1e-7)
    end

    it "atan" do
      Math.atan(4.3_f32).should be_close(1.3422996875030344, 1e-7)
      Math.atan(4.3).should be_close(1.3422996875030344, 1e-7)
    end

    it "atan2" do
      Math.atan2(3.5_f32, 2.1_f32).should be_close(1.0303768265243125, 1e-7)
      Math.atan2(3.5, 2.1).should be_close(1.0303768265243125, 1e-7)
      Math.atan2(1, 0).should eq(Math.atan2(1.0, 0.0))
    end
  end

  describe "Hyperbolic functions" do
    it "cosh" do
      Math.cosh(0.79_f32).should be_close(1.3286206107691463, 1e-7)
      Math.cosh(0.79).should be_close(1.3286206107691463, 1e-7)
    end

    it "sinh" do
      Math.sinh(0.12_f32).should be_close(0.12028820743110909, 1e-7)
      Math.sinh(0.12).should be_close(0.12028820743110909, 1e-7)
    end

    it "tanh" do
      Math.tanh(4.1_f32).should be_close(0.9994508436877974, 1e-7)
      Math.tanh(4.1).should be_close(0.9994508436877974, 1e-7)
    end
  end

  describe "Inverse hyperbolic functions" do
    it "acosh" do
      Math.acosh(1.1_f32).should be_close(0.4435682543851154, 1e-7)
      Math.acosh(1.1).should be_close(0.4435682543851154, 1e-7)
    end

    it "asinh" do
      Math.asinh(-2.3_f32).should be_close(-1.570278543484978, 1e-7)
      Math.asinh(-2.3).should be_close(-1.570278543484978, 1e-7)
    end

    it "atanh" do
      Math.atanh(0.13_f32).should be_close(0.13073985002887845, 1e-7)
      Math.atanh(0.13).should be_close(0.13073985002887845, 1e-7)
    end
  end

  describe "Gamma functions" do
    it "gamma" do
      Math.gamma(3.2_f32).should be_close(2.4239654799353683, 1e-6)
      Math.gamma(3.2).should be_close(2.4239654799353683, 1e-7)
      Math.gamma(5).should eq 24
      Math.gamma(5_i8).should eq 24
    end

    it "lgamma" do
      Math.lgamma(2.96_f32).should be_close(0.6565534110944214, 1e-7)
      Math.lgamma(2.96).should be_close(0.6565534110944214, 1e-7)
      Math.lgamma(3).should be_close(0.6931471805599454, 1e-7)
      Math.lgamma(3_i8).should be_close(0.6931471805599454, 1e-7)
    end
  end

  describe "Bessel functions" do
    it "besselj0" do
      Math.besselj0(9.1_f32).should be_close(-0.11423923268319867, 1e-7)
      Math.besselj0(9.1).should be_close(-0.11423923268319867, 1e-7)
    end

    it "besselj1" do
      Math.besselj1(-2.1_f32).should be_close(-0.5682921357570385, 1e-7)
      Math.besselj1(-2.1).should be_close(-0.5682921357570385, 1e-7)
    end

    it "besselj" do
      Math.besselj(4, -6.4_f32).should be_close(0.2945338623574655, 1e-7)
      Math.besselj(4, -6.4).should be_close(0.2945338623574655, 1e-7)
    end

    it "bessely0" do
      Math.bessely0(2.14_f32).should be_close(0.5199289108068015, 1e-7)
      Math.bessely0(2.14).should be_close(0.5199289108068015, 1e-7)
    end

    it "bessely1" do
      Math.bessely1(7.7_f32).should be_close(-0.2243184743430081, 1e-7)
      Math.bessely1(7.7).should be_close(-0.2243184743430081, 1e-7)
    end

    it "bessely" do
      Math.bessely(3, 2.7_f32).should be_close(-0.6600575162477298, 1e-7)
      Math.bessely(3, 2.7).should be_close(-0.6600575162477298, 1e-7)
    end
  end

  describe "Gauss error functions" do
    it "erf" do
      Math.erf(0.72_f32).should be_close(0.6914331231387512, 1e-7)
      Math.erf(0.72).should be_close(0.6914331231387512, 1e-7)
    end

    it "erfc" do
      Math.erfc(-0.66_f32).should be_close(1.6493766879629543, 1e-7)
      Math.erfc(-0.66).should be_close(1.6493766879629543, 1e-7)
    end
  end

  # div rem

  it "fma" do
    x = Math.fma(0.1, 10.0, -1.0)
    x.should be_close(5.551115123125783e-17, 1e-25)
    x.should_not eq(0.0)

    x = Math.fma(0.1_f32, 10.0_f32, -1.0_f32)
    x.should be_close(1.4901161e-8_f32, 1e-16_f32)
    x.should_not eq(0.0_f32)
  end

  describe ".pw2ceil" do
    {% for int in %w(Int8 Int16 Int32 Int64 Int128) %}
      it {{ int }} do
        Math.pw2ceil({{ int.id }}::MIN).should eq 1
        Math.pw2ceil({{ int.id }}::MIN + 1).should eq 1
        Math.pw2ceil({{ int.id }}.new(-11)).should eq 1
        Math.pw2ceil({{ int.id }}.new(-1)).should eq 1
        Math.pw2ceil({{ int.id }}.new(0)).should eq 1
        Math.pw2ceil({{ int.id }}.new(1)).should eq 1
        Math.pw2ceil({{ int.id }}.new(2)).should eq 2
        Math.pw2ceil({{ int.id }}.new(3)).should eq 4
        Math.pw2ceil({{ int.id }}.new(4)).should eq 4
        Math.pw2ceil({{ int.id }}.new(5)).should eq 8
        Math.pw2ceil({{ int.id }}.new(32)).should eq(32)
        Math.pw2ceil({{ int.id }}.new(33)).should eq(64)
        Math.pw2ceil({{ int.id }}.new(64)).should eq(64)

        Math.pw2ceil({{ int.id }}::MAX // 2).should eq({{ int.id }}::MAX // 2 + 1)
        Math.pw2ceil({{ int.id }}::MAX // 2 + 1).should eq({{ int.id }}::MAX // 2 + 1)
        expect_raises(OverflowError) { Math.pw2ceil({{ int.id }}::MAX // 2 + 2) }
        expect_raises(OverflowError) { Math.pw2ceil({{ int.id }}::MAX) }
      end
    {% end %}

    {% for uint in %w(UInt8 UInt16 UInt32 UInt64 UInt128) %}
      it {{ uint }} do
        Math.pw2ceil({{ uint.id }}.new(0)).should eq 1
        Math.pw2ceil({{ uint.id }}.new(1)).should eq 1
        Math.pw2ceil({{ uint.id }}.new(2)).should eq 2
        Math.pw2ceil({{ uint.id }}.new(3)).should eq 4
        Math.pw2ceil({{ uint.id }}.new(4)).should eq 4
        Math.pw2ceil({{ uint.id }}.new(5)).should eq 8
        Math.pw2ceil({{ uint.id }}.new(32)).should eq(32)
        Math.pw2ceil({{ uint.id }}.new(33)).should eq(64)
        Math.pw2ceil({{ uint.id }}.new(64)).should eq(64)

        Math.pw2ceil({{ uint.id }}::MAX // 2).should eq({{ uint.id }}::MAX // 2 + 1)
        Math.pw2ceil({{ uint.id }}::MAX // 2 + 1).should eq({{ uint.id }}::MAX // 2 + 1)
        expect_raises(OverflowError) { Math.pw2ceil({{ uint.id }}::MAX // 2 + 2) }
        expect_raises(OverflowError) { Math.pw2ceil({{ uint.id }}::MAX) }
      end
    {% end %}
  end

  # ** (float and int)
end
