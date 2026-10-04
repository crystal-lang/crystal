require "spec"

describe "Crystal.once" do
  it "runs the initializer once" do
    flag = false
    count = 0
    2.times { Crystal.once(pointerof(flag)) { count += 1 } }
    count.should eq(1)
  end

  it "runs the initializer again after it raised" do
    flag = false
    expect_raises(Exception, "boom") do
      Crystal.once(pointerof(flag)) { raise "boom" }
    end

    ran = false
    Crystal.once(pointerof(flag)) { ran = true }
    ran.should be_true
    flag.should be_true
  end

  it "doesn't report recursion for another flag after an initializer raised" do
    failing = false
    expect_raises(Exception, "boom") do
      Crystal.once(pointerof(failing)) { raise "boom" }
    end

    other = false
    ran = false
    Crystal.once(pointerof(other)) { ran = true }
    ran.should be_true
  end
end
