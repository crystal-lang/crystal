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

  it "raises on invalid range" do
    expect_raises ArgumentError, "incorrect rand value: 1...1" do
      rand(1...1)
    end
  end

  it "gets a random bool" do
    Random::DEFAULT.next_bool.should be_a(Bool)
  end
end
