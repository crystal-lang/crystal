require 'spec_helper'

describe 'Type inference: NoReturn' do
  it "types call to C.exit as NoReturn" do
    assert_type(%q(require "prelude"; C.exit 0)) { no_return }
  end

  it "types raise as NoReturn" do
    assert_type(%q(require "prelude"; raise "foo")) { no_return }
  end

  it "types union of NoReturn and something else" do
    assert_type(%q(require "prelude"; true ? raise "foo" : 1)) { int }
  end

  it "types union of NoReturns" do
    assert_type(%q(require "prelude"; true ? raise "foo" : raise "foo")) { no_return }
  end
end
