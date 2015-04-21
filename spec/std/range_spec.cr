require "spec"

describe "Range" do
  it "gets basic properties" do
    r = 1 .. 5
    expect(r.begin).to eq(1)
    expect(r.end).to eq(5)
    expect(r.excludes_end?).to be_false

    r = 1 ... 5
    expect(r.begin).to eq(1)
    expect(r.end).to eq(5)
    expect(r.excludes_end?).to be_true
  end

  it "includes?" do
    expect((1 .. 5).includes?(1)).to be_true
    expect((1 .. 5).includes?(5)).to be_true

    expect((1 ... 5).includes?(1)).to be_true
    expect((1 ... 5).includes?(5)).to be_false
  end

  it "does to_s" do
    expect((1...5).to_s).to eq("1...5")
    expect((1..5).to_s).to eq("1..5")
  end

  it "does inspect" do
    expect((1...5).inspect).to eq("1...5")
  end
end
