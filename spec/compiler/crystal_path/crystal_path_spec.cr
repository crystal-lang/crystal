#!/usr/bin/env bin/crystal --run
require "../../spec_helper"

describe Crystal::CrystalPath do
  it "finds file with .cr extension" do
    path = Crystal::CrystalPath.new(__DIR__)
    matches = path.find "test_files/file_one.cr"
    matches.should eq(["#{__DIR__}/test_files/file_one.cr"])
  end

  it "finds file without .cr extension" do
    path = Crystal::CrystalPath.new(__DIR__)
    matches = path.find "test_files/file_one"
    matches.should eq(["#{__DIR__}/test_files/file_one.cr"])
  end

  it "finds all files with *" do
    path = Crystal::CrystalPath.new(__DIR__)
    matches = path.find "test_files/*"
    matches.should eq([
      "#{__DIR__}/test_files/file_one.cr",
      "#{__DIR__}/test_files/file_two.cr",
      ])
  end

  it "finds all files with **" do
    path = Crystal::CrystalPath.new(__DIR__)
    matches = path.find "test_files/**"
    matches.should eq([
      "#{__DIR__}/test_files/file_one.cr",
      "#{__DIR__}/test_files/file_two.cr",
      "#{__DIR__}/test_files/test_folder/file_three.cr",
      "#{__DIR__}/test_files/test_folder/test_folder.cr",
      ])
  end

  it "finds file in directory with its basename" do
    path = Crystal::CrystalPath.new(__DIR__)
    matches = path.find "test_files/test_folder"
    matches.should eq([
      "#{__DIR__}/test_files/test_folder/test_folder.cr",
      ])
  end

  it "finds file relative to another one" do
    path = Crystal::CrystalPath.new(__DIR__)
    matches = path.find "file_two.cr", relative_to: "#{__DIR__}/test_files/file_one.cr"
    matches.should eq([
      "#{__DIR__}/test_files/file_two.cr",
      ])
  end

  it "finds file relative to another one with directory" do
    path = Crystal::CrystalPath.new(__DIR__)
    matches = path.find "test_folder/file_three.cr", relative_to: "#{__DIR__}/test_files/file_one.cr"
    matches.should eq([
      "#{__DIR__}/test_files/test_folder/file_three.cr",
      ])
  end

  it "finds files with * relative to another one" do
    path = Crystal::CrystalPath.new(__DIR__)
    matches = path.find "test_folder/*", relative_to: "#{__DIR__}/test_files/file_one.cr"
    matches.should eq([
      "#{__DIR__}/test_files/test_folder/file_three.cr",
      "#{__DIR__}/test_files/test_folder/test_folder.cr",
      ])
  end

  it "finds files with ** relative to another one" do
    path = Crystal::CrystalPath.new(__DIR__)
    matches = path.find "../**", relative_to: "#{__DIR__}/test_files/test_folder/file_three.cr"
    matches.should eq([
      "#{__DIR__}/test_files/file_one.cr",
      "#{__DIR__}/test_files/file_two.cr",
      "#{__DIR__}/test_files/test_folder/file_three.cr",
      "#{__DIR__}/test_files/test_folder/test_folder.cr",
      ])
  end

  it "doesn't find file with .cr extension" do
    path = Crystal::CrystalPath.new(__DIR__)
    expect_raises Exception, /can't find file/ do
      path.find "test_files/missing_file.cr"
    end
  end
end
