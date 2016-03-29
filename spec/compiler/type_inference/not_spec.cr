require "../../spec_helper"

describe "Type inference: not" do
  it "types not" do
    assert_type(%(
      !1
      )) { bool }
  end

  it "types not as NoReturn if exp is NoReturn" do
    assert_type(%(
      lib LibC
        fun exit : NoReturn
      end

      !LibC.exit
      )) { no_return }
  end
end
