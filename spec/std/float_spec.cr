require "spec"

describe "Float" do
  describe "**" do
    assert { expect((2.5_f32 ** 2_i32)).to eq(6.25_f32) }
    assert { expect((2.5_f32 ** 2)).to eq(6.25_f32) }
    assert { expect((2.5_f32 ** 2.5_f32)).to eq(9.882117688026186_f32) }
    assert { expect((2.5_f32 ** 2.5)).to eq(9.882117688026186_f32) }
    assert { expect((2.5_f64 ** 2_i32)).to eq(6.25_f64) }
    assert { expect((2.5_f64 ** 2)).to eq(6.25_f64) }
    assert { expect((2.5_f64 ** 2.5_f64)).to eq(9.882117688026186_f64) }
    assert { expect((2.5_f64 ** 2.5)).to eq(9.882117688026186_f64) }
  end

  describe "round" do
    assert { expect(2.5.round).to eq(3) }
    assert { expect(2.4.round).to eq(2) }
  end

  describe "floor" do
    assert { expect(2.1.floor).to eq(2) }
    assert { expect(2.9.floor).to eq(2) }
  end

  describe "ceil" do
    assert { expect(2.0_f32.ceil).to eq(2) }
    assert { expect(2.0.ceil).to eq(2) }

    assert { expect(2.1_f32.ceil).to eq(3_f32) }
    assert { expect(2.1.ceil).to eq(3) }

    assert { expect(2.9_f32.ceil).to eq(3) }
    assert { expect(2.9.ceil).to eq(3) }
  end

  describe "fdiv" do
    assert { expect(1.0.fdiv(1)).to eq 1.0 }
    assert { expect(1.0.fdiv(2)).to eq 0.5 }
    assert { expect(1.0.fdiv(0.5)).to eq 2.0 }
    assert { expect(0.0.fdiv(1)).to eq 0.0 }
    assert { expect(1.0.fdiv(0)).to eq 1.0/0.0 }
  end

  describe "to_s" do
    it "does to_s for f32 and f64" do
      expect(12.34.to_s).to eq("12.34")
      expect(12.34_f64.to_s).to eq("12.34")
    end
  end

  describe "hash" do
    it "does for Float32" do
      expect(1.2_f32.hash).to_not eq(0)
    end

    it "does for Float64" do
      expect(1.2.hash).to_not eq(0)
    end
  end

  it "casts" do
    expect(Float32.cast(1_f64)).to be_a(Float32)
    expect(Float32.cast(1_f64)).to eq(1)

    expect(Float64.cast(1_f32)).to be_a(Float64)
    expect(Float64.cast(1_f32)).to eq(1)
  end

  it "does nan?" do
    expect(1.5.nan?).to be_false
    expect((0.0 / 0.0).nan?).to be_true
  end

  it "does infinite?" do
    expect((0.0).infinite?).to be_nil
    expect((-1.0/0.0).infinite?).to eq(-1)
    expect((1.0/0.0).infinite?).to eq(1)

    expect((0.0_f32).infinite?).to be_nil
    expect((-1.0_f32/0.0_f32).infinite?).to eq(-1)
    expect((1.0_f32/0.0_f32).infinite?).to eq(1)
  end

  it "does finite?" do
    expect(0.0.finite?).to be_true
    expect(1.5.finite?).to be_true
    expect((1.0/0.0).finite?).to be_false
    expect((-1.0/0.0).finite?).to be_false
    expect((-0.0/0.0).finite?).to be_false
  end
end
