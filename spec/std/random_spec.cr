require "spec"

describe "Random" do
  it "limited number" do
    expect(rand(1)).to eq(0)

    x = rand(2)
    expect(x).to be >= 0
    expect(x).to be < 2
  end

  it "float number" do
    x = rand
    expect(x).to be > 0
    expect(x).to be < 1
  end

  it "raises on invalid number" do
    expect_raises ArgumentError, "incorrect rand value: 0" do
      rand(0)
    end
  end

  it "does with inclusive range" do
    expect(rand(1..1)).to eq(1)
    x = rand(1..3)
    expect(x).to be >= 1
    expect(x).to be <= 3
  end

  it "does with exclusive range" do
    expect(rand(1...2)).to eq(1)
    x = rand(1...4)
    expect(x).to be >= 1
    expect(x).to be < 4
  end

  it "raises on invalid range" do
    expect_raises ArgumentError, "incorrect rand value: 1...1" do
      rand(1...1)
    end
  end

  it "allows creating a new default random" do
    rand = Random.new
    value = rand.rand
    expect((0 <= value < 1)).to be_true
  end

  it "allows creating a new default random with a seed" do
    rand = Random.new(1234)
    value1 = rand.rand

    rand = Random.new(1234)
    value2 = rand.rand

    expect(value1).to eq(value2)
  end

  it "gets a random bool" do
    expect(Random::DEFAULT.next_bool).to be_a(Bool)
  end
end
