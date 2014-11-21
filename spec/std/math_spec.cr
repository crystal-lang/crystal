require "spec"

describe "Math" do
  describe "cos" do
    assert { Math.cos(0.5).should be_close(0.877583, 1e-5) }
    assert { Math.cos(0.5_f32).should be_close(0.877583, 1e-5) }
  end

  describe "exp" do
    assert { Math.exp(0.5).should be_close(1.64872, 1e-5) }
    assert { Math.exp(0.5_f32).should be_close(1.64872, 1e-5) }
  end

  describe "E" do
    assert { Math::E.should be_close(2.71828, 1e-5) }
  end

  describe "log" do
    assert { Math.log(0.5).should be_close(-0.693147, 1e-5) }
    assert { Math.log(0.5_f32).should be_close(-0.693147, 1e-5) }
  end

  describe "log2" do
    assert { Math.log2(0.5).should be_close(-1, 1e-5) }
    assert { Math.log2(0.5_f32).should be_close(-1, 1e-5) }
  end

  describe "log10" do
    assert { Math.log10(0.5).should be_close(-0.30103, 1e-5) }
    assert { Math.log10(0.5_f32).should be_close(-0.30103, 1e-5) }
  end

  describe "min" do
    assert { Math.min(1, 2).should eq(1) }
    assert { Math.min(2, 1).should eq(1) }
  end

  describe "max" do
    assert { Math.max(1, 2).should eq(2) }
    assert { Math.max(2, 1).should eq(2) }
  end

  describe "sin" do
    assert { Math.sin(0.5).should be_close(0.479426, 1e-5) }
    assert { Math.sin(0.5_f32).should be_close(0.479426, 1e-5) }
  end

  describe "sqrt" do
    assert { Math.sqrt(4).should eq(2) }
    assert { Math.sqrt(81.0).should eq(9.0) }
    assert { Math.sqrt(81.0_f32).should eq(9.0) }
  end
end
