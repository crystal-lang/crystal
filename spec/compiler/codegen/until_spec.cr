require "../../spec_helper"

describe "Codegen: until" do
  it "codegens until" do
    expect(run(%(
      require "bool"

      a = 1
      until a == 10
        a = a + 1
      end
      a
    )).to_i).to eq(10)
  end

  it "codegens until as modifier" do
    expect(run(%(
      require "bool"

      a = 1
      begin
        a += 1
      end until a >= 1
      a
    )).to_i).to eq(2)
  end
end
