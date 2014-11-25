require "../../spec_helper"

describe "Code gen: alias" do
  it "invokes methods on empty array of recursive alias (1)" do
    run(%(
      require "prelude"

      alias X = Array(X)

      a = [] of X
      b = a.map(&.to_s).join
      )).to_string.should eq("")
  end

  it "invokes methods on empty array of recursive alias (2)" do
    run(%(
      require "prelude"

      alias X = Nil | Array(X)

      a = [] of X
      b = a.map(&.to_s).join
      )).to_string.should eq("")
  end

  it "invokes methods on empty array of recursive alias (3)" do
    run(%(
      require "prelude"

      alias X = Nil | Array(X)

      a = [] of X
      b = a.map(&.to_s).join
      )).to_string.should eq("")
  end
end
