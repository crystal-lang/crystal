#!/usr/bin/env bin/crystal --run
require "spec"

describe "Dir" do
  it "tests exists? on existing directory" do
    Dir.exists?(File.join([__DIR__, "../"])).should be_true
  end

  it "tests exists? on existing file" do
    Dir.exists?(__FILE__).should be_false
  end

  it "tests exists? on nonexistent directory" do
    Dir.exists?(File.join([__DIR__, "/foo/bar/"])).should be_false
  end

  it "tests mkdir and rmdir with a new path" do
    path = "/tmp/crystal_mkdir_test_#{Process.pid}/"
    Dir.mkdir(path, 0700).should eq(0)
    Dir.exists?(path).should be_true
    Dir.rmdir(path).should eq(0)
    Dir.exists?(path).should be_false
  end

  it "tests mkdir with an existing path" do
    expect_raises Errno do
      Dir.mkdir(__DIR__, 0700)
    end
  end

  it "tests mkdir_p with a new path" do
    path = "/tmp/crystal_mkdir_ptest_#{Process.pid}/"
    Dir.mkdir_p(path).should eq(0)
    Dir.exists?(path).should be_true
    path = File.join({path, "a", "b", "c"})
    Dir.mkdir_p(path).should eq(0)
    Dir.exists?(path).should be_true
  end

  it "tests mkdir_p with an existing path" do
    Dir.mkdir_p(__DIR__).should eq(0)
    expect_raises Errno do
      Dir.mkdir_p(__FILE__)
    end
  end

  it "tests rmdir with an nonexistent path" do
    expect_raises Errno do
      Dir.rmdir("/tmp/crystal_mkdir_test_#{Process.pid}/")
    end
  end

  it "tests rmdir with a path that cannot be removed" do
    expect_raises Errno do
      Dir.rmdir(__DIR__)
    end
  end
end
