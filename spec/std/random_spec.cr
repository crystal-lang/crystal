require "spec"

describe "Random" do
  it "limited number" do
    rand(1).should eq(0)

    x = rand(2)
    x.should be >= 0
    x.should be < 2
  end

  it "float number" do
    x = rand
    x.should be > 0
    x.should be < 1
  end

  it "limited float number" do
    x = rand(3.5)
    x.should be >= 0
    x.should be < 3.5
  end

  it "raises on invalid number" do
    expect_raises ArgumentError, "incorrect rand value: 0" do
      rand(0)
    end
  end

  it "does with inclusive range" do
    rand(1..1).should eq(1)
    x = rand(1..3)
    x.should be >= 1
    x.should be <= 3
  end

  it "does with exclusive range" do
    rand(1...2).should eq(1)
    x = rand(1...4)
    x.should be >= 1
    x.should be < 4
  end

  it "does with inclusive range of floats" do
    rand(1.0..1.0).should eq(1.0)
    x = rand(1.8..3.2)
    x.should be >= 1.8
    x.should be <= 3.2
  end

  it "does with exclusive range of floats" do
    x = rand(1.8...3.3)
    x.should be >= 1.8
    x.should be < 3.3
  end

  it "raises on invalid range" do
    expect_raises ArgumentError, "incorrect rand value: 1...1" do
      rand(1...1)
    end
  end

  it "allows creating a new default random" do
    rand = Random.new
    value = rand.rand
    (0 <= value < 1).should be_true
  end

  it "allows creating a new default random with a seed" do
    rand = Random.new(1234)
    value1 = rand.rand

    rand = Random.new(1234)
    value2 = rand.rand

    value1.should eq(value2)
  end

  it "gets a random bool" do
    Random::DEFAULT.next_bool.should be_a(Bool)
  end
end
