require "spec"

describe "Float" do
  describe "**" do
    assert { (2.5_f32 ** 2_i32).should be_close(6.25_f32, 0.0001) }
    assert { (2.5_f32 ** 2).should be_close(6.25_f32, 0.0001) }
    assert { (2.5_f32 ** 2.5_f32).should be_close(9.882117688026186_f32, 0.0001) }
    assert { (2.5_f32 ** 2.5).should be_close(9.882117688026186_f32, 0.0001) }
    assert { (2.5_f64 ** 2_i32).should be_close(6.25_f64, 0.0001) }
    assert { (2.5_f64 ** 2).should be_close(6.25_f64, 0.0001) }
    assert { (2.5_f64 ** 2.5_f64).should be_close(9.882117688026186_f64, 0.0001) }
    assert { (2.5_f64 ** 2.5).should be_close(9.882117688026186_f64, 0.001) }
  end

  describe "%" do
    it "uses modulo behavior, not remainder behavior" do
      assert { ((-11.5) % 4.0).should eq(0.5) }
    end
  end

  describe "modulo" do
    it "raises when mods by zero" do
      expect_raises(DivisionByZero) { 1.2.modulo 0.0 }
    end

    assert { (13.0.modulo 4.0).should eq(1.0) }
    assert { (13.0.modulo -4.0).should eq(-3.0) }
    assert { (-13.0.modulo 4.0).should eq(3.0) }
    assert { (-13.0.modulo -4.0).should eq(-1.0) }
    assert { (11.5.modulo 4.0).should eq(3.5) }
    assert { (11.5.modulo -4.0).should eq(-0.5) }
    assert { (-11.5.modulo 4.0).should eq(0.5) }
    assert { (-11.5.modulo -4.0).should eq(-3.5) }
  end

  describe "remainder" do
    it "raises when mods by zero" do
      expect_raises(DivisionByZero) { 1.2.remainder 0.0 }
    end

    assert { (13.0.remainder 4.0).should eq(1.0) }
    assert { (13.0.remainder -4.0).should eq(1.0) }
    assert { (-13.0.remainder 4.0).should eq(-1.0) }
    assert { (-13.0.remainder -4.0).should eq(-1.0) }
    assert { (11.5.remainder 4.0).should eq(3.5) }
    assert { (11.5.remainder -4.0).should eq(3.5) }
    assert { (-11.5.remainder 4.0).should eq(-3.5) }
    assert { (-11.5.remainder -4.0).should eq(-3.5) }
  end

  describe "round" do
    assert { 2.5.round.should eq(3) }
    assert { 2.4.round.should eq(2) }
  end

  describe "floor" do
    assert { 2.1.floor.should eq(2) }
    assert { 2.9.floor.should eq(2) }
  end

  describe "ceil" do
    assert { 2.0_f32.ceil.should eq(2) }
    assert { 2.0.ceil.should eq(2) }

    assert { 2.1_f32.ceil.should eq(3_f32) }
    assert { 2.1.ceil.should eq(3) }

    assert { 2.9_f32.ceil.should eq(3) }
    assert { 2.9.ceil.should eq(3) }
  end

  describe "fdiv" do
    assert { 1.0.fdiv(1).should eq 1.0 }
    assert { 1.0.fdiv(2).should eq 0.5 }
    assert { 1.0.fdiv(0.5).should eq 2.0 }
    assert { 0.0.fdiv(1).should eq 0.0 }
    assert { 1.0.fdiv(0).should eq 1.0/0.0 }
  end

  describe "to_s" do
    it "does to_s for f32 and f64" do
      12.34.to_s.should eq("12.34")
      12.34_f64.to_s.should eq("12.34")
    end
  end

  describe "hash" do
    it "does for Float32" do
      1.2_f32.hash.should_not eq(0)
    end

    it "does for Float64" do
      1.2.hash.should_not eq(0)
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
end
