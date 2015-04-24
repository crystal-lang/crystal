require "spec"

describe "Math" do
  describe "Mathematical constants" do
    it "E" do
      expect(Math::E).to be_close(2.718281828459045, 1e-7)
    end

    it "LOG2" do
      expect(Math::LOG2).to be_close(0.6931471805599453, 1e-7)
    end

    it "LOG10" do
      expect(Math::LOG10).to be_close(2.302585092994046, 1e-7)
    end
  end

  describe "Functions manipulating signs" do
    it "copysign" do
      expect(Math.copysign(6.9, -0.2)).to eq(-6.9)
    end
  end

  describe "Order-related functions" do
    expect(Math.min(2.1, 2.11)).to eq(2.1)
    expect(Math.max(3.2, 3.11)).to eq(3.2)
  end

  pending "Functions for computing quotient and remainder" do
  end

  describe "Roots" do
    it "cbrt" do
      expect(Math.cbrt(6.5_f32)).to be_close(1.866255578408624, 1e-7)
      expect(Math.cbrt(6.5)).to be_close(1.866255578408624, 1e-7)
    end

    it "sqrt" do
      expect(Math.sqrt(5.2_f32)).to be_close(2.280350850198276, 1e-7)
      expect(Math.sqrt(5.2)).to be_close(2.280350850198276, 1e-7)
      expect(Math.sqrt(4_f32)).to eq(2)
      expect(Math.sqrt(4)).to eq(2)
    end
  end

  describe "Exponents" do
    it "exp" do
      expect(Math.exp(0.211_f32)).to be_close(1.2349123550613943, 1e-7)
      expect(Math.exp(0.211)).to be_close(1.2349123550613943, 1e-7)
    end

    it "exp2" do
      expect(Math.exp2(0.41_f32)).to be_close(1.3286858140965117, 1e-7)
      expect(Math.exp2(0.41)).to be_close(1.3286858140965117, 1e-7)
    end

    it "expm1" do
      expect(Math.expm1(0.99_f32)).to be_close(1.6912344723492623, 1e-7)
      expect(Math.expm1(0.99)).to be_close(1.6912344723492623, 1e-7)
    end

    it "ilogb" do
      expect(Math.ilogb(0.5_f32)).to eq(-1)
      expect(Math.ilogb(0.5)).to eq(-1)
    end

    it "ldexp" do
      expect(Math.ldexp(0.27_f32, 2)).to be_close(1.08, 1e-7)
      expect(Math.ldexp(0.27, 2)).to be_close(1.08, 1e-7)
    end

    it "logb" do
      expect(Math.logb(10_f32)).to be_close(3.0, 1e-7)
      expect(Math.logb(10.0)).to be_close(3.0, 1e-7)
    end

    it "scalbn" do
      expect(Math.scalbn(0.2_f32, 3)).to be_close(1.6, 1e-7)
      expect(Math.scalbn(0.2, 3)).to be_close(1.6, 1e-7)
    end

    it "scalbln" do
      expect(Math.scalbln(0.11_f32, 2)).to be_close(0.44, 1e-7)
      expect(Math.scalbln(0.11, 2)).to be_close(0.44, 1e-7)
    end
  end

  describe "Logarithms" do
    it "log" do
      expect(Math.log(3.24_f32)).to be_close(1.1755733298042381, 1e-7)
      expect(Math.log(3.24)).to be_close(1.1755733298042381, 1e-7)
      expect(Math.log(0.3_f32, 3)).to be_close(-1.0959032742893848, 1e-7)
      expect(Math.log(0.3, 3)).to be_close(-1.0959032742893848, 1e-7)
    end

    it "log2" do
      expect(Math.log2(1.2_f32)).to be_close(0.2630344058337938, 1e-7)
      expect(Math.log2(1.2)).to be_close(0.2630344058337938, 1e-7)
    end

    it "log10" do
      expect(Math.log10(0.5_f32)).to be_close(-0.3010299956639812, 1e-7)
      expect(Math.log10(0.5)).to be_close(-0.3010299956639812, 1e-7)
    end

    it "log1p" do
      expect(Math.log1p(0.67_f32)).to be_close(0.5128236264286637, 1e-7)
      expect(Math.log1p(0.67)).to be_close(0.5128236264286637, 1e-7)
    end
  end

  describe "Trigonometric functions" do
    it "cos" do
      expect(Math.cos(2.23_f32)).to be_close(-0.6124875656583851, 1e-7)
      expect(Math.cos(2.23)).to be_close(-0.6124875656583851, 1e-7)
    end

    it "sin" do
      expect(Math.sin(3.3_f32)).to be_close(-0.1577456941432482, 1e-7)
      expect(Math.sin(3.3)).to be_close(-0.1577456941432482, 1e-7)
    end

    it "tan" do
      expect(Math.tan(0.91_f32)).to be_close(1.2863693807208076, 1e-7)
      expect(Math.tan(0.91)).to be_close(1.2863693807208076, 1e-7)
    end

    it "hypot" do
      expect(Math.hypot(2.1_f32, 1.5_f32)).to be_close(2.5806975801127883, 1e-7)
      expect(Math.hypot(2.1, 1.5)).to be_close(2.5806975801127883, 1e-7)
    end
  end

  describe "Inverse trigonometric functions" do
    it "acos" do
      expect(Math.acos(0.125_f32)).to be_close(1.445468495626831, 1e-7)
      expect(Math.acos(0.125)).to be_close(1.445468495626831, 1e-7)
    end

    it "asin" do
      expect(Math.asin(-0.4_f32)).to be_close(-0.41151684606748806, 1e-7)
      expect(Math.asin(-0.4)).to be_close(-0.41151684606748806, 1e-7)
    end

    it "atan" do
      expect(Math.atan(4.3_f32)).to be_close(1.3422996875030344, 1e-7)
      expect(Math.atan(4.3)).to be_close(1.3422996875030344, 1e-7)
    end

    it "atan2" do
      expect(Math.atan2(3.5_f32, 2.1_f32)).to be_close(1.0303768265243125, 1e-7)
      expect(Math.atan2(3.5, 2.1)).to be_close(1.0303768265243125, 1e-7)
    end
  end

  describe "Hyperbolic functions" do
    it "cosh" do
      expect(Math.cosh(0.79_f32)).to be_close(1.3286206107691463, 1e-7)
      expect(Math.cosh(0.79)).to be_close(1.3286206107691463, 1e-7)
    end

    it "sinh" do
      expect(Math.sinh(0.12_f32)).to be_close(0.12028820743110909, 1e-7)
      expect(Math.sinh(0.12)).to be_close(0.12028820743110909, 1e-7)
    end

    it "tanh" do
      expect(Math.tanh(4.1_f32)).to be_close(0.9994508436877974, 1e-7)
      expect(Math.tanh(4.1)).to be_close(0.9994508436877974, 1e-7)
    end
  end

  describe "Inverse hyperbolic functions" do
    it "acosh" do
      expect(Math.acosh(1.1_f32)).to be_close(0.4435682543851154, 1e-7)
      expect(Math.acosh(1.1)).to be_close(0.4435682543851154, 1e-7)
    end

    it "asinh" do
      expect(Math.asinh(-2.3_f32)).to be_close(-1.570278543484978, 1e-7)
      expect(Math.asinh(-2.3)).to be_close(-1.570278543484978, 1e-7)
    end

    it "atanh" do
      expect(Math.atanh(0.13_f32)).to be_close(0.13073985002887845, 1e-7)
      expect(Math.atanh(0.13)).to be_close(0.13073985002887845, 1e-7)
    end
  end

  describe "Gamma functions" do
    it "gamma" do
      expect(Math.gamma(3.2_f32)).to be_close(2.4239654799353683, 1e-6)
      expect(Math.gamma(3.2)).to be_close(2.4239654799353683, 1e-7)
    end

    it "lgamma" do
      expect(Math.lgamma(2.96_f32)).to be_close(0.6565534110944214, 1e-7)
      expect(Math.lgamma(2.96)).to be_close(0.6565534110944214, 1e-7)
    end
  end

  describe "Bessel functions" do
    it "besselj0" do
      expect(Math.besselj0(9.1_f32)).to be_close(-0.11423923268319867, 1e-7)
      expect(Math.besselj0(9.1)).to be_close(-0.11423923268319867, 1e-7)
    end

    it "besselj1" do
      expect(Math.besselj1(-2.1_f32)).to be_close(-0.5682921357570385, 1e-7)
      expect(Math.besselj1(-2.1)).to be_close(-0.5682921357570385, 1e-7)
    end

    it "besselj" do
      expect(Math.besselj(4, -6.4_f32)).to be_close(0.2945338623574655, 1e-7)
      expect(Math.besselj(4, -6.4)).to be_close(0.2945338623574655, 1e-7)
    end

    it "bessely0" do
      expect(Math.bessely0(2.14_f32)).to be_close(0.5199289108068015, 1e-7)
      expect(Math.bessely0(2.14)).to be_close(0.5199289108068015, 1e-7)
    end

    it "bessely1" do
      expect(Math.bessely1(7.7_f32)).to be_close(-0.2243184743430081, 1e-7)
      expect(Math.bessely1(7.7)).to be_close(-0.2243184743430081, 1e-7)
    end

    it "bessely" do
      expect(Math.bessely(3, 2.7_f32)).to be_close(-0.6600575162477298, 1e-7)
      expect(Math.bessely(3, 2.7)).to be_close(-0.6600575162477298, 1e-7)
    end
  end

  describe "Gauss error functions" do
    it "erf" do
      expect(Math.erf(0.72_f32)).to be_close(0.6914331231387512, 1e-7)
      expect(Math.erf(0.72)).to be_close(0.6914331231387512, 1e-7)
    end

    it "erfc" do
      expect(Math.erfc(-0.66_f32)).to be_close(1.6493766879629543, 1e-7)
      expect(Math.erfc(-0.66)).to be_close(1.6493766879629543, 1e-7)
    end
  end

# div rem

# pw2ceil

# ** (float and int)
end
