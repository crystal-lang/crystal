require 'spec_helper'

describe 'Codegen: is_a?' do
  it "codegens is_a? true for simple type" do
    run("1.is_a?(Int)").to_b.should be_true
  end

  it "codegens is_a? false for simple type" do
    run("1.is_a?(Bool)").to_b.should be_false
  end

  it "codegens is_a? with union gives true" do
    run("(true ? 1 : 'a').is_a?(Int)").to_b.should be_true
  end

  it "codegens is_a? with union gives false" do
    run("(true ? 1 : 'a').is_a?(Char)").to_b.should be_false
  end

  it "codegens is_a? with union gives false" do
    run("(true ? 1 : 'a').is_a?(Float)").to_b.should be_false
  end

  it "codegens is_a? with nilable gives true" do
    run("(true ? nil : Object.new).is_a?(Nil)").to_b.should be_true
  end

  it "codegens is_a? with nilable gives false becuase other type 1" do
    run("(true ? nil : Object.new).is_a?(Object)").to_b.should be_false
  end

  it "codegens is_a? with nilable gives false becuase other type 2" do
    run("(false ? nil : Object.new).is_a?(Object)").to_b.should be_true
  end

  it "codegens is_a? with nilable gives false becuase no type" do
    run("(false ? nil : Object.new).is_a?(String)").to_b.should be_false
  end

  it "codegens is_a? with nilable gives false becuase no type" do
    run("1.is_a?(Object)").to_b.should be_true
  end

  it "evaluate method on filtered type" do
    run("a = 1; a = 'a'; if a.is_a?(Char); a.ord; else; 0; end").to_i.should eq(?a.ord)
  end
end
