#!/usr/bin/env bin/crystal --run
require "spec"
require "objc"

describe "ObjCClass" do
  describe "name" do
    ObjCClass.new("NSString").name.should eq("NSString")
  end
end

describe "NSString" do
  describe "length" do
    "".to_nsstring.length.should eq(0)
    "a".to_nsstring.length.should eq(1)
    "lorem".to_nsstring.length.should eq(5)
  end

  describe "[]" do
    "a".to_nsstring[0].should eq('a')
    "lorem".to_nsstring[2].should eq('r')
  end

  describe "to_s" do
    "lorem".to_nsstring.to_s.should eq("lorem")
  end
end

describe "NSObject" do
  describe "objc_class" do
    "a".to_nsstring.objc_class.name.should eq("__NSCFConstantString")
  end
end

describe "NSMutableArray" do
  describe "count" do
    NSMutableArray.new.count.should eq(0)
    NSMutableArray.new.tap do |a|
      a << "foo".to_nsstring
      a.count.should eq(1)
    end
  end

  describe "index" do
    NSMutableArray.new.tap do |a|
      a << "foo".to_nsstring
      a[0].is_a?(NSString).should eq(true)
      a[0].to_s.should eq("foo")
    end
  end
end
