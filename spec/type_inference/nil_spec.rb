require 'spec_helper'

describe 'Type inference: nil' do
  it "types nil" do
    assert_type('nil') { self.nil }
  end

  it "can call a fun with nil for pointer" do
    assert_type(%q(lib A; fun a(c : Char*) : Int; end; A.a(nil))) { int }
  end
end
