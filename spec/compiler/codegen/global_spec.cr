require "../../spec_helper"

describe "Code gen: global" do
  it "codegens global" do
    expect(run("$foo = 1; def foo; $foo = 2; end; foo; $foo").to_i).to eq(2)
  end

  it "codegens global with union" do
    expect(run("$foo = 1; def foo; $foo = 2.5_f32; end; foo; $foo.to_f").to_f64).to eq(2.5)
  end

  it "codegens global when not initialized" do
    expect(run("require \"nil\"; $foo.to_i").to_i).to eq(0)
  end

  it "codegens global when not initialized" do
    expect(run("require \"nil\"; def foo; $foo = 2 if 1 == 2; end; foo; $foo.to_i").to_i).to eq(0)
  end
end
