require "../../spec_helper"

describe "Code gen: varargs" do
  it "can generate code for 'fun' with varargs" do
    mod = codegen(%(
      fun foo(...) : Void
      end

      foo
    ))
    str = mod.to_s
    str.should contain(%(define void @foo(...) #0 {))
  end

  it "can generate code for 'fun' with varargs" do
    mod = codegen(%(
      foo = ->(...) do
      end
    ))
    str = mod.to_s
    str.should contain(%(define void @"~procProc(Nil)@:3"(...) #0 {))
  end
end
