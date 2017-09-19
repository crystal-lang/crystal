require "spec"

describe "unreachable!" do
  it "raises UnreachableError with 'BUG: unreachable' message" do
    expect_raises(UnreachableError, "BUG: unreachable") { unreachable! }
  end

  it "can set an error message" do
    expect_raises UnreachableError, "i'm bag" do
      unreachable! "i'm bag"
    end
  end
end
