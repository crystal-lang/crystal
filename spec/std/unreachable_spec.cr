describe unreachable! do
  it "raises an exception" do
    expect_raises(Exception, "BUG: unreachable") do
      unreachable!
    end
  end

  it "raises a custom message" do
    expect_raises(Exception, "This is a custom message") do
      unreachable! "This is a custom message"
    end
  end
end
