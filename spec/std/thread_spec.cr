require "spec"

describe Thread do
  it "allows passing an argumentless fun to execute" do
    a = 0
    thread = Thread.new { a = 1; 10 }
    thread.join
    a.should eq(1)
  end

  it "raises inside thread and gets it on join" do
    thread = Thread.new { raise "OH NO" }
    expect_raises Exception, "OH NO" do
      thread.join
    end
  end
end
