require "../../spec_helper"

describe "Codegen: until" do
  it "codegens until" do
    run(<<-CRYSTAL).to_i.should eq(10)
      a = 1
      until a == 10
        a = a &+ 1
      end
      a
      CRYSTAL
  end
end
