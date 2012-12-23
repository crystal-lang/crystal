require 'spec_helper'

describe 'Type inference: def overload' do
  it "types a call with overload" do
    assert_type('def foo; 1; end; def foo(x); 2.5; end; foo') { int }
  end

  it "types a call with overload with yield" do
    assert_type('def foo; yield; 1; end; def foo; 2.5; end; foo') { float }
  end

  it "types a call with overload with yield the other way" do
    assert_type('def foo; yield; 1; end; def foo; 2.5; end; foo { 1 }') { int }
  end

  it "types a call with overload type first overload" do
    assert_type('def foo(x : Int); 2.5; end; def foo(x : Float); 1; end; foo(1)') { float }
  end

  it "types a call with overload type second overload" do
    assert_type('def foo(x : Int); 2.5; end; def foo(x : Float); 1; end; foo(1.5)') { int }
  end
end
