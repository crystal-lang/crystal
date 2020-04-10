require "../../../../spec_helper"
require "../../../../support/tempfile"

private alias ProjectInfo = Crystal::Doc::ProjectInfo

describe Crystal::Doc::ProjectInfo do
  it ".new_with_defaults" do
    with_tempfile("docs-defaults") do |tempdir|
      Dir.mkdir tempdir
      Dir.cd(tempdir) do
        # Empty dir
        ProjectInfo.new_with_defaults(nil, nil) { |name, version| "missing:#{name}:#{version}" }.should eq "missing::"
        ProjectInfo.new_with_defaults("foo", "1.0") { |name, version| "missing:#{name}:#{version}" }.should eq ProjectInfo.new("foo", "1.0")

        # shard.yml
        File.write("shard.yml", "name: foo\nversion: 1.0")
        ProjectInfo.new_with_defaults(nil, nil) { |name, version| "missing:#{name}:#{version}" }.should eq ProjectInfo.new("foo", "1.0")
        ProjectInfo.new_with_defaults("bar", "2.0") { |name, version| "missing:#{name}:#{version}" }.should eq ProjectInfo.new("bar", "2.0")
        ProjectInfo.new_with_defaults(nil, "2.0") { |name, version| "missing:#{name}:#{version}" }.should eq ProjectInfo.new("foo", "2.0")

        # git tagged version
        `git init`
        `git add shard.yml`
        `git commit -m 'Initial commit' --no-gpg-sign`
        `git tag v3.0`
        ProjectInfo.new_with_defaults(nil, nil) { |name, version| "missing:#{name}:#{version}" }.should eq ProjectInfo.new("foo", "3.0")
        ProjectInfo.new_with_defaults("bar", "2.0") { |name, version| "missing:#{name}:#{version}" }.should eq ProjectInfo.new("bar", "2.0")

        # git dirty dir
        File.write("foo.txt", "bar")
        ProjectInfo.new_with_defaults(nil, nil) { |name, version| "missing:#{name}:#{version}" }.should eq ProjectInfo.new("foo", "1.0")
        ProjectInfo.new_with_defaults(nil, "1.1") { |name, version| "missing:#{name}:#{version}" }.should eq ProjectInfo.new("foo", "1.1")
        ProjectInfo.new_with_defaults("bar", "2.0") { |name, version| "missing:#{name}:#{version}" }.should eq ProjectInfo.new("bar", "2.0")
        File.delete("foo.txt")

        # No shard.yml, but git version
        `git rm shard.yml`
        `git commit -m 'Remove shard.yml' --no-gpg-sign`
        `git tag v4.0`
        ProjectInfo.new_with_defaults(nil, nil) { |name, version| "missing:#{name}:#{version}" }.should eq "missing::4.0"
        ProjectInfo.new_with_defaults("foo", nil) { |name, version| "missing:#{name}:#{version}" }.should eq ProjectInfo.new("foo", "4.0")
        ProjectInfo.new_with_defaults("bar", "2.0") { |name, version| "missing:#{name}:#{version}" }.should eq ProjectInfo.new("bar", "2.0")
      end
    end
  end

  it ".find_git_version" do
    with_tempfile("docs-git-version") do |tempdir|
      Dir.mkdir tempdir
      Dir.cd(tempdir) do
        # Non-git directory
        ProjectInfo.find_git_version.should be_nil

        `git init`
        ProjectInfo.find_git_version.should be_nil

        File.write("file.txt", "foo")
        `git add file.txt`
        `git commit -m 'Initial commit' --no-gpg-sign`
        ProjectInfo.find_git_version.should be_nil

        `git tag v0.1.0`
        ProjectInfo.find_git_version.should eq "0.1.0"

        File.write("file.txt", "bar")
        ProjectInfo.find_git_version.should be_nil

        `git add file.txt`
        ProjectInfo.find_git_version.should be_nil

        `git reset --hard v0.1.0`
        ProjectInfo.find_git_version.should eq "0.1.0"

        `git tag v0.2.0`
        ProjectInfo.find_git_version.should be_nil
      end
    end
  end

  it ".read_shard_properties" do
    with_tempfile("docs-shard.yml") do |tempdir|
      Dir.mkdir tempdir
      Dir.cd(tempdir) do
        ProjectInfo.read_shard_properties.should eq({nil, nil})

        File.write("shard.yml", "foo: bar\n")
        ProjectInfo.read_shard_properties.should eq({nil, nil})

        File.write("shard.yml", "name: \nversion: ")
        ProjectInfo.read_shard_properties.should eq({nil, nil})

        File.write("shard.yml", "  name: bar\n  version: 1.0")
        ProjectInfo.read_shard_properties.should eq({nil, nil})

        File.write("shard.yml", "name: bar\n")
        ProjectInfo.read_shard_properties.should eq({"bar", nil})

        File.write("shard.yml", "name: bar\nversion: 1.0")
        ProjectInfo.read_shard_properties.should eq({"bar", "1.0"})

        File.write("shard.yml", "name: bar\nversion: 1.0\nname: foo\nversion: foo")
        ProjectInfo.read_shard_properties.should eq({"bar", "1.0"})

        File.write("shard.yml", "name: bar  \nversion: 1.0  ")
        ProjectInfo.read_shard_properties.should eq({"bar", "1.0"})

        File.write("shard.yml", "name: 'bar'\nversion: '1.0'")
        ProjectInfo.read_shard_properties.should eq({"bar", "1.0"})

        File.write("shard.yml", "name: bar # comment\nversion: 1.0 # comment")
        ProjectInfo.read_shard_properties.should eq({"bar", "1.0"})

        File.write("shard.yml", "name: # comment\nversion: # comment")
        ProjectInfo.read_shard_properties.should eq({nil, nil})
      end
    end
  end
end
