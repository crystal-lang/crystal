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

  # The order of the following 4 tests matters.
  it "tests mkdir with a nonexistent path" do
    path = "/tmp/crystal_mkdir_test_#{Process.pid}/"
    Dir.mkdir(path, 0700).should eq(0)
  end

  it "tests mkdir with an existing path" do
    path = "/tmp/crystal_mkdir_test_#{Process.pid}/"
    begin
      Dir.mkdir(path, 0700)
      fail "Expected Errno to be raised"
    rescue Errno
    end
  end

  it "tests rmdir with an existing path" do
    path = "/tmp/crystal_mkdir_test_#{Process.pid}/"
    Dir.rmdir(path).should eq(0)
  end

  it "tests rmddir with an nonexistent path" do
    path = "/tmp/crystal_mkdir_test_#{Process.pid}/"
    begin
      Dir.rmdir(path)
      fail "Expected Errno to be raised"
    rescue Errno
    end
  end
end
