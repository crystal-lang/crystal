require "spec"
require "complex"

describe "Complex" do
  it "i" do
    a = 4.5 + 6.7.i
    b = Complex.new(4.5, 6.7)
    c = Complex.new(4.5, 9.6)
    a.should eq(b)
    a.should_not eq(c)
  end

  describe "==" do
    it "complex == complex" do
      a = Complex.new(1.5, 2)
      b = Complex.new(1.5, 2)
      c = Complex.new(2.25, 3)
      (a == b).should be_true
      (a == c).should be_false
    end

    it "complex == number" do
      a = Complex.new(5.3, 0)
      b = 5.3
      c = 4.2
      (a == b).should be_true
      (a == c).should be_false
    end

    it "number == complex" do
      a = -1.75
      b = Complex.new(-1.75, 0)
      c = Complex.new(7.2, 0)
      (a == b).should be_true
      (a == c).should be_false
    end
  end

  it "to_s" do
    Complex.new(1.25, 8.2).to_s.should eq("1.25 + 8.2i")
    Complex.new(1.25, -8.2).to_s.should eq("1.25 - 8.2i")
  end

  it "inspect" do
    Complex.new(1.25, 8.2).inspect.should eq("(1.25 + 8.2i)")
    Complex.new(1.25, -8.2).inspect.should eq("(1.25 - 8.2i)")
  end

  it "abs" do
    Complex.new(5.1, 9.7).abs.should eq(10.959014554237985)
  end

  it "abs2" do
    Complex.new(-1.1, 9).abs2.should eq(82.21)
  end

  it "sign" do
    Complex.new(-1.4, 7.7).sign.should eq(Complex.new(-0.17888543819998315, 0.9838699100999074))
  end

  it "phase" do
    Complex.new(11.5, -6.25).phase.should eq(-0.4978223326170012)
  end

  it "polar" do
    Complex.new(7.25, -13.1).polar.should eq({14.972391258579906, -1.0653196179316864})
  end

  it "cis" do
    2.4.cis.should eq(Complex.new(-0.7373937155412454, 0.675463180551151))
  end

  it "conj" do
    Complex.new(10.1, 3.7).conj.should eq(Complex.new(10.1, -3.7))
  end

  it "inv" do
    Complex.new(1.5, -2.5).inv.should eq(Complex.new(0.17647058823529413, 0.29411764705882354))
  end

  it "sqrt" do
    Complex.new(1.32, 7.25).sqrt.should be_close(Complex.new(2.0843687106374236, 1.739135682425128), 1e-15)
    Complex.new(7.11, -0.9).sqrt.should be_close(Complex.new(2.671772413453534, -0.1684275194002508), 1e-15)
    Complex.new(-2.2, 6.22).sqrt.should be_close(Complex.new(1.4828360708935342, 2.0973323087062226), 1e-15)
    Complex.new(-8.3, -1.11).sqrt.should be_close(Complex.new(0.1922159681400434, -2.8873771797962275), 1e-15)
  end

  it "exp" do
    Complex.new(1.15, -5.1).exp.should be_close(Complex.new(1.1937266270566773, 2.923901365414129), 1e-15)
  end

  describe "logarithms" do
    it "log" do
      Complex.new(1.25, -4.7).log.should eq(Complex.new(1.5817344087982312, -1.3108561866063686))
    end

    it "log2" do
      Complex.new(-9.1, 3.2).log2.should eq(Complex.new(3.2699671225858946, +4.044523592551345))
    end

    it "log10" do
      Complex.new(2.11, 1.21).log10.should eq(Complex.new(0.38602142355392594, +0.22612668967405536))
    end
  end

  describe "+" do
    it "complex + complex" do
      (Complex.new(2.2, 7) + Complex.new(10.1, 1.34)).should eq(Complex.new(12.3, 8.34))
    end

    it "complex + number" do
      (Complex.new(0.3, 5.5) + 15).should eq(Complex.new(15.3, 5.5))
    end

    it "number + complex" do
      (-1.7 + Complex.new(7, 4.1)).should eq(Complex.new(5.3, 4.1))
    end
  end

  describe "-" do
    it "- complex" do
      (-Complex.new(5.43, 27.12)).should eq(Complex.new(-5.43, -27.12))
    end

    it "complex - complex" do
      (Complex.new(21.7, 2.0) - Complex.new(0.15, 3.4)).should eq(Complex.new(21.55, -1.4))
    end

    it "complex - number" do
      (Complex.new(8.1, 6.15) - 15).should eq(Complex.new(-6.9, 6.15))
    end

    it "number - complex" do
      (-3.27 - Complex.new(7, 5.1)).should eq(Complex.new(-10.27, -5.1))
    end
  end

  describe "*" do
    it "complex * complex" do
      (Complex.new(12.2, 9.8)*Complex.new(4.78, 2.86)).should eq(Complex.new(30.288, 81.736))
    end

    it "complex * number" do
      (Complex.new(11.3, 15.25)*1.2).should eq(Complex.new(13.56, 18.3))
    end

    it "number * complex" do
      (-1.7*Complex.new(9.7, 3.22)).should eq(Complex.new(-16.49, -5.474))
    end
  end

  describe "/" do
    it "complex / complex" do
      ((Complex.new(4, 6.2))/(Complex.new(0.5, 2.7))).should eq(Complex.new(2.485411140583554, -1.0212201591511936))
      ((Complex.new(4.1, 6.0))/(Complex.new(10, 2.2))).should eq(Complex.new(0.5169782525753529, 0.48626478443342236))
    end

    it "complex / number" do
      ((Complex.new(21.3, 5.8))/1.9).should eq(Complex.new(11.210526315789474, 3.0526315789473686))
    end

    it "number / complex" do
      (-5.7/(Complex.new(2.27, 8.92))).should eq(Complex.new(-0.1527278908111847, 0.6001466017778712))
    end
  end

  it "clones" do
    c = Complex.new(4, 6.2)
    c.clone.should eq(c)
  end

  it "test zero?" do
    Complex.new(0, 0).zero?.should eq true
    Complex.new(0, 3.4).zero?.should eq false
    Complex.new(1.2, 0).zero?.should eq false
    Complex.new(1.2, 3.4).zero?.should eq false
  end
end
