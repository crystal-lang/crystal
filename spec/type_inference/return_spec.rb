require 'spec_helper'

describe 'Type inference: return' do
  it "infers return type" do
    assert_type("def foo; return 1; end; foo") { int }
  end

  it "infers return type with many returns" do
    assert_type("def foo; if true; return 1; end; 2.5 end; foo") { union_of(int, double) }
  end
end
