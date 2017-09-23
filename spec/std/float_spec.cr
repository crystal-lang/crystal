require "spec"

describe "Float" do
  describe "**" do
    it { (2.5_f32 ** 2_i32).should be_close(6.25_f32, 0.0001) }
    it { (2.5_f32 ** 2).should be_close(6.25_f32, 0.0001) }
    it { (2.5_f32 ** 2.5_f32).should be_close(9.882117688026186_f32, 0.0001) }
    it { (2.5_f32 ** 2.5).should be_close(9.882117688026186_f32, 0.0001) }
    it { (2.5_f64 ** 2_i32).should be_close(6.25_f64, 0.0001) }
    it { (2.5_f64 ** 2).should be_close(6.25_f64, 0.0001) }
    it { (2.5_f64 ** 2.5_f64).should be_close(9.882117688026186_f64, 0.0001) }
    it { (2.5_f64 ** 2.5).should be_close(9.882117688026186_f64, 0.001) }
  end

  describe "%" do
    it "uses modulo behavior, not remainder behavior" do
      it { ((-11.5) % 4.0).should eq(0.5) }
    end
  end

  describe "modulo" do
    it "raises when mods by zero" do
      expect_raises(DivisionByZero) { 1.2.modulo 0.0 }
    end

    it { (13.0.modulo 4.0).should eq(1.0) }
    it { (13.0.modulo -4.0).should eq(-3.0) }
    it { (-13.0.modulo 4.0).should eq(3.0) }
    it { (-13.0.modulo -4.0).should eq(-1.0) }
    it { (11.5.modulo 4.0).should eq(3.5) }
    it { (11.5.modulo -4.0).should eq(-0.5) }
    it { (-11.5.modulo 4.0).should eq(0.5) }
    it { (-11.5.modulo -4.0).should eq(-3.5) }
  end

  describe "remainder" do
    it "raises when mods by zero" do
      expect_raises(DivisionByZero) { 1.2.remainder 0.0 }
    end

    it { (13.0.remainder 4.0).should eq(1.0) }
    it { (13.0.remainder -4.0).should eq(1.0) }
    it { (-13.0.remainder 4.0).should eq(-1.0) }
    it { (-13.0.remainder -4.0).should eq(-1.0) }
    it { (11.5.remainder 4.0).should eq(3.5) }
    it { (11.5.remainder -4.0).should eq(3.5) }
    it { (-11.5.remainder 4.0).should eq(-3.5) }
    it { (-11.5.remainder -4.0).should eq(-3.5) }

    it "preserves type" do
      r = 1.5_f32.remainder(1)
      typeof(r).should eq(Float32)
    end
  end

  describe "round" do
    it { 2.5.round.should eq(3) }
    it { 2.4.round.should eq(2) }
  end

  describe "floor" do
    it { 2.1.floor.should eq(2) }
    it { 2.9.floor.should eq(2) }
  end

  describe "ceil" do
    it { 2.0_f32.ceil.should eq(2) }
    it { 2.0.ceil.should eq(2) }

    it { 2.1_f32.ceil.should eq(3_f32) }
    it { 2.1.ceil.should eq(3) }

    it { 2.9_f32.ceil.should eq(3) }
    it { 2.9.ceil.should eq(3) }
  end

  describe "fdiv" do
    it { 1.0.fdiv(1).should eq 1.0 }
    it { 1.0.fdiv(2).should eq 0.5 }
    it { 1.0.fdiv(0.5).should eq 2.0 }
    it { 0.0.fdiv(1).should eq 0.0 }
    it { 1.0.fdiv(0).should eq 1.0/0.0 }
  end

  describe "divmod" do
    it { 1.2.divmod(0.3)[0].should eq(4) }
    it { 1.2.divmod(0.3)[1].should be_close(0.0, 0.00001) }

    it { 1.3.divmod(0.3)[0].should eq(4) }
    it { 1.3.divmod(0.3)[1].should be_close(0.1, 0.00001) }

    it { 1.4.divmod(0.3)[0].should eq(4) }
    it { 1.4.divmod(0.3)[1].should be_close(0.2, 0.00001) }

    it { -1.2.divmod(0.3)[0].should eq(-4) }
    it { -1.2.divmod(0.3)[1].should be_close(0.0, 0.00001) }

    it { -1.3.divmod(0.3)[0].should eq(-5) }
    it { -1.3.divmod(0.3)[1].should be_close(0.2, 0.00001) }

    it { -1.4.divmod(0.3)[0].should eq(-5) }
    it { -1.4.divmod(0.3)[1].should be_close(0.1, 0.00001) }

    it { 1.2.divmod(-0.3)[0].should eq(-4) }
    it { 1.2.divmod(-0.3)[1].should be_close(0.0, 0.00001) }

    it { 1.3.divmod(-0.3)[0].should eq(-5) }
    it { 1.3.divmod(-0.3)[1].should be_close(-0.2, 0.00001) }

    it { 1.4.divmod(-0.3)[0].should eq(-5) }
    it { 1.4.divmod(-0.3)[1].should be_close(-0.1, 0.00001) }

    it { -1.2.divmod(-0.3)[0].should eq(4) }
    it { -1.2.divmod(-0.3)[1].should be_close(0.0, 0.00001) }

    it { -1.3.divmod(-0.3)[0].should eq(4) }
    it { -1.3.divmod(-0.3)[1].should be_close(-0.1, 0.00001) }

    it { -1.4.divmod(-0.3)[0].should eq(4) }
    it { -1.4.divmod(-0.3)[1].should be_close(-0.2, 0.00001) }
  end

  describe "to_s" do
    it "does to_s for f64" do
      12.34.to_s.should eq("12.34")
      1.2.to_s.should eq("1.2")
      1.23.to_s.should eq("1.23")
      1.234.to_s.should eq("1.234")
      0.65000000000000002.to_s.should eq("0.65")
      1.234001.to_s.should eq("1.234001")
      1.23499.to_s.should eq("1.23499")
      1.23499999999999999.to_s.should eq("1.235")
      1.2345.to_s.should eq("1.2345")
      1.23456.to_s.should eq("1.23456")
      1.234567.to_s.should eq("1.234567")
      1.2345678.to_s.should eq("1.2345678")
      1.23456789.to_s.should eq("1.23456789")
      1.234567891.to_s.should eq("1.234567891")
      1.2345678911.to_s.should eq("1.2345678911")
      1.2345678912.to_s.should eq("1.2345678912")
      1.23456789123.to_s.should eq("1.23456789123")
      9525365.25.to_s.should eq("9525365.25")
      12.9999.to_s.should eq("12.9999")
      12.9999999999999999.to_s.should eq("13.0")
      1.0.to_s.should eq("1.0")
      2e20.to_s.should eq("2.0e+20")
      1e-10.to_s.should eq("1.0e-10")
      1464132168.65.to_s.should eq("1464132168.65")
      146413216.865.to_s.should eq("146413216.865")
      14641321.6865.to_s.should eq("14641321.6865")
      1464132.16865.to_s.should eq("1464132.16865")
      654329382.1.to_s.should eq("654329382.1")
      6543293824.1.to_s.should eq("6543293824.1")
      65432938242.1.to_s.should eq("65432938242.1")
      654329382423.1.to_s.should eq("654329382423.1")
      6543293824234.1.to_s.should eq("6543293824234.1")
      65432938242345.1.to_s.should eq("65432938242345.1")
      65432.123e20.to_s.should eq("6.5432123e+24")
      65432.123e200.to_s.should eq("6.5432123e+204")
      -65432.123e200.to_s.should eq("-6.5432123e+204")
      65432.123456e20.to_s.should eq("6.5432123456e+24")
      65432.1234567e20.to_s.should eq("6.54321234567e+24")
      65432.12345678e20.to_s.should eq("6.543212345678e+24")
      65432.1234567891e20.to_s.should eq("6.54321234567891e+24")
      (1.0/0.0).to_s.should eq("Infinity")
      (-1.0/0.0).to_s.should eq("-Infinity")
      (0.999999999999999989).to_s.should eq("1.0")
    end

    it "does to_s for f32" do
      12.34_f32.to_s.should eq("12.34")
      1.2_f32.to_s.should eq("1.2")
      1.23_f32.to_s.should eq("1.23")
      1.234_f32.to_s.should eq("1.234")
      0.65000000000000002_f32.to_s.should eq("0.65")
      # 1.234001_f32.to_s.should eq("1.234001")
      1.23499_f32.to_s.should eq("1.23499")
      1.23499999999999_f32.to_s.should eq("1.235")
      1.2345_f32.to_s.should eq("1.2345")
      1.23456_f32.to_s.should eq("1.23456")
      # 9525365.25_f32.to_s.should eq("9525365.25")
      (1.0_f32/0.0_f32).to_s.should eq("Infinity")
      (-1.0_f32/0.0_f32).to_s.should eq("-Infinity")
    end
  end

  describe "#inspect" do
    it "does inspect for f64" do
      3.2.inspect.should eq("3.2")
    end

    it "does inspect for f32" do
      3.2_f32.inspect.should eq("3.2_f32")
    end

    it "does inspect for f64 with IO" do
      str = String.build { |io| 3.2.inspect(io) }
      str.should eq("3.2")
    end

    it "does inspect for f32" do
      str = String.build { |io| 3.2_f32.inspect(io) }
      str.should eq("3.2_f32")
    end
  end

  describe "hash" do
    it "does for Float32" do
      1.2_f32.hash.should eq(1.2_f32.hash)
    end

    it "does for Float64" do
      1.2.hash.should eq(1.2.hash)
    end
  end

  it "casts" do
    Float32.new(1_f64).should be_a(Float32)
    Float32.new(1_f64).should eq(1)

    Float64.new(1_f32).should be_a(Float64)
    Float64.new(1_f32).should eq(1)
  end

  it "does nan?" do
    1.5.nan?.should be_false
    (0.0 / 0.0).nan?.should be_true
  end

  it "does infinite?" do
    (0.0).infinite?.should be_nil
    (-1.0/0.0).infinite?.should eq(-1)
    (1.0/0.0).infinite?.should eq(1)

    (0.0_f32).infinite?.should be_nil
    (-1.0_f32/0.0_f32).infinite?.should eq(-1)
    (1.0_f32/0.0_f32).infinite?.should eq(1)
  end

  it "does finite?" do
    0.0.finite?.should be_true
    1.5.finite?.should be_true
    (1.0/0.0).finite?.should be_false
    (-1.0/0.0).finite?.should be_false
    (-0.0/0.0).finite?.should be_false
  end

  it "does unary -" do
    f = -(1.5)
    f.should eq(-1.5)
    f.should be_a(Float64)

    f = -(1.5_f32)
    f.should eq(-1.5_f32)
    f.should be_a(Float32)
  end

  it "clones" do
    1.0.clone.should eq(1.0)
    1.0_f32.clone.should eq(1.0_f32)
  end
end
