require "spec"

describe Thread do
  it "allows passing an argumentless fun to execute" do
    a = 0
    thread = Thread.new { a = 1; 10 }
    thread.join.should eq(10)
    a.should eq(1)
  end

  it "allows passing a fun with an argument to execute" do
    a = 0
    thread = Thread.new(3) { |i| a += i; 20 }
    thread.join.should eq(20)
    a.should eq(3)
  end

  it "raises inside thread and gets it on join" do
    thread = Thread.new { raise "OH NO" }
    expect_raises Exception, "OH NO" do
      thread.join
    end
  end

  it "gets a non-nilable value from join" do
    thread = Thread.new { 1 }
    value = thread.join
    (value + 2).should eq(3)
  end
end
