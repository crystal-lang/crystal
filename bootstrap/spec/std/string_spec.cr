#!/usr/bin/env bin/crystal -run
require "spec"

describe "String" do
  describe "[]" do
    it "gets with positive index" do
      "hello!"[1].should eq('e')
    end

    it "gets with negative index" do
      "hello!"[-1].should eq('!')
    end

    it "gets with inclusive range" do
      "hello!"[1 .. 4].should eq("ello")
    end

    it "gets with inclusive range with negative indices" do
      "hello!"[-5 .. -2].should eq("ello")
    end

    it "gets with exclusive range" do
      "hello!"[1 ... 4].should eq("ell")
    end

    it "gets with start and count" do
      "hello"[1, 3].should eq("ell")
    end
  end

  it "does to_i" do
    "1234".to_i.should eq(1234)
  end

  it "does to_f" do
    "1234.56".to_f.should eq(1234.56f)
  end

  it "does to_d" do
    "1234.56".to_d.should eq(1234.56)
  end

  it "compares strings: different length" do
    "foo".should_not eq("fo")
  end

  it "compares strings: same object" do
    f = "foo"
    f.should eq(f)
  end

  it "compares strings: same length, same string" do
    "foo".should eq("fo" + "o")
  end

  it "compares strings: same length, different string" do
    "foo".should_not eq("bar")
  end

  it "interpolates string" do
    foo = "<foo>"
    bar = 123
    "foo #{bar}".should eq("foo 123")
    "foo #{ bar}".should eq("foo 123")
    "#{foo} bar".should eq("<foo> bar")
  end

  it "multiplies" do
    str = "foo"
    (str * 0).should eq("")
    (str * 3).should eq("foofoofoo")
  end

  describe "downcase" do
    assert { "HELLO!".downcase.should eq("hello!") }
    assert { "HELLO MAN!".downcase.should eq("hello man!") }
  end

  describe "upcase" do
    assert { "hello!".upcase.should eq("HELLO!") }
    assert { "hello man!".upcase.should eq("HELLO MAN!") }
  end

  describe "capitalize" do
    assert { "HELLO!".capitalize.should eq("Hello!") }
    assert { "HELLO MAN!".capitalize.should eq("Hello man!") }
  end
end