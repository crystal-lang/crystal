require "../../../../spec_helper"
require "../../../../support/tempfile"

private alias ProjectInfo = Crystal::Doc::ProjectInfo

private def run_git(command)
  Process.run(%(git -c user.email="" -c user.name="spec" #{command}), shell: true)
end

private def assert_with_defaults(initial, expected, *, file = __FILE__, line = __LINE__)
  initial.fill_with_defaults
  initial.should eq(expected), file: file, line: line
end

describe Crystal::Doc::ProjectInfo do
  around_each do |example|
    with_tempfile("docs-project") do |tempdir|
      Dir.mkdir tempdir
      Dir.cd(tempdir) do
        example.run
      end
    end
  end

  describe "#fill_with_defaults" do
    it "empty folder" do
      assert_with_defaults(ProjectInfo.new(nil, nil), ProjectInfo.new(nil, nil))
      assert_with_defaults(ProjectInfo.new("foo", "1.0"), ProjectInfo.new("foo", "1.0"))
    end

    context "with shard.yml" do
      before_each do
        File.write("shard.yml", "name: foo\nversion: 1.0")
      end

      it "no git" do
        assert_with_defaults(ProjectInfo.new(nil, nil), ProjectInfo.new("foo", "1.0"))
        assert_with_defaults(ProjectInfo.new("bar", "2.0"), ProjectInfo.new("bar", "2.0"))
        assert_with_defaults(ProjectInfo.new(nil, "2.0"), ProjectInfo.new("foo", "2.0"))
      end

      it "git but no commit" do
        run_git "init"

        assert_with_defaults(ProjectInfo.new(nil, nil), ProjectInfo.new("foo", nil))
        assert_with_defaults(ProjectInfo.new("bar", "2.0"), ProjectInfo.new("bar", "2.0"))
        assert_with_defaults(ProjectInfo.new(nil, "2.0"), ProjectInfo.new("foo", "2.0"))
      end

      it "git tagged version" do
        run_git "init"
        run_git "add shard.yml"
        run_git "commit -m 'Initial commit' --no-gpg-sign"
        run_git "tag v3.0"

        assert_with_defaults(ProjectInfo.new(nil, nil), ProjectInfo.new("foo", "3.0"))
        assert_with_defaults(ProjectInfo.new("bar", "2.0"), ProjectInfo.new("bar", "2.0"))
      end

      it "git tagged version dirty" do
        run_git "init"
        run_git "add shard.yml"
        run_git "commit -m 'Initial commit' --no-gpg-sign"
        run_git "tag v3.0"
        File.write("foo.txt", "bar")

        assert_with_defaults(ProjectInfo.new(nil, nil), ProjectInfo.new("foo", "3.0-dev"))
        assert_with_defaults(ProjectInfo.new(nil, "1.1"), ProjectInfo.new("foo", "1.1"))
        assert_with_defaults(ProjectInfo.new("bar", "2.0"), ProjectInfo.new("bar", "2.0"))
      end

      it "git non-tagged commit" do
        run_git "init"
        run_git "add shard.yml"
        run_git "commit -m 'Initial commit' --no-gpg-sign"

        assert_with_defaults(ProjectInfo.new(nil, nil), ProjectInfo.new("foo", "master"))
        assert_with_defaults(ProjectInfo.new(nil, "1.1"), ProjectInfo.new("foo", "1.1"))
        assert_with_defaults(ProjectInfo.new("bar", "2.0"), ProjectInfo.new("bar", "2.0"))
      end

      it "git non-tagged commit dirty" do
        run_git "init"
        run_git "add shard.yml"
        run_git "commit -m 'Initial commit' --no-gpg-sign"
        File.write("foo.txt", "bar")

        assert_with_defaults(ProjectInfo.new(nil, nil), ProjectInfo.new("foo", "master-dev"))
        assert_with_defaults(ProjectInfo.new(nil, "1.1"), ProjectInfo.new("foo", "1.1"))
        assert_with_defaults(ProjectInfo.new("bar", "2.0"), ProjectInfo.new("bar", "2.0"))
      end
    end

    it "no shard.yml, but git tagged version" do
      File.write("foo.txt", "bar")
      run_git "init"
      run_git "add foo.txt"
      run_git "commit -m 'Remove shard.yml' --no-gpg-sign"
      run_git "tag v4.0"

      assert_with_defaults(ProjectInfo.new(nil, nil), ProjectInfo.new(nil, "4.0"))
      assert_with_defaults(ProjectInfo.new("foo", nil), ProjectInfo.new("foo", "4.0"))
      assert_with_defaults(ProjectInfo.new("bar", "2.0"), ProjectInfo.new("bar", "2.0"))
    end
  end

  it ".find_git_version" do
    # Non-git directory
    ProjectInfo.find_git_version.should be_nil

    # Empty git directory
    run_git "init"
    ProjectInfo.find_git_version.should be_nil

    # Non-tagged commit
    File.write("file.txt", "foo")
    run_git "add file.txt"
    run_git "commit -m 'Initial commit' --no-gpg-sign"
    ProjectInfo.find_git_version.should eq "master"

    # Other branch
    run_git "checkout -b foo"
    ProjectInfo.find_git_version.should eq "foo"

    # Non-tagged commit, dirty workdir
    run_git "checkout master"
    File.write("file.txt", "bar")
    ProjectInfo.find_git_version.should eq "master-dev"

    run_git "checkout -- ."

    # Tagged commit
    run_git "tag v0.1.0"
    ProjectInfo.find_git_version.should eq "0.1.0"

    # Tagged commit, dirty workdir
    File.write("file.txt", "bar")
    ProjectInfo.find_git_version.should eq "0.1.0-dev"

    # Tagged commit, dirty index
    run_git "add file.txt"
    ProjectInfo.find_git_version.should eq "0.1.0-dev"

    run_git "reset --hard v0.1.0"
    ProjectInfo.find_git_version.should eq "0.1.0"

    # Multiple tags
    run_git "tag v0.2.0"
    ProjectInfo.find_git_version.should eq "0.1.0"
  end

  describe ".read_shard_properties" do
    it "no shard.yml" do
      ProjectInfo.read_shard_properties.should eq({nil, nil})
    end

    it "without name and version properties" do
      File.write("shard.yml", "foo: bar\n")
      ProjectInfo.read_shard_properties.should eq({nil, nil})
    end

    it "empty properties" do
      File.write("shard.yml", "name: \nversion: ")
      ProjectInfo.read_shard_properties.should eq({nil, nil})
    end

    it "indented properties" do
      File.write("shard.yml", "  name: bar\n  version: 1.0")
      ProjectInfo.read_shard_properties.should eq({nil, nil})
    end

    it "only name" do
      File.write("shard.yml", "name: bar\n")
      ProjectInfo.read_shard_properties.should eq({"bar", nil})
    end

    it "name and version" do
      File.write("shard.yml", "name: bar\nversion: 1.0")
      ProjectInfo.read_shard_properties.should eq({"bar", "1.0"})
    end

    it "duplicate properties uses first one" do
      File.write("shard.yml", "name: bar\nversion: 1.0\nname: foo\nversion: foo")
      ProjectInfo.read_shard_properties.should eq({"bar", "1.0"})
    end

    it "strip whitespace" do
      File.write("shard.yml", "name: bar  \nversion: 1.0  ")
      ProjectInfo.read_shard_properties.should eq({"bar", "1.0"})
    end

    it "strip quotes" do
      File.write("shard.yml", "name: 'bar'\nversion: '1.0'")
      ProjectInfo.read_shard_properties.should eq({"bar", "1.0"})
    end

    it "ignores comments" do
      File.write("shard.yml", "name: bar # comment\nversion: 1.0 # comment")
      ProjectInfo.read_shard_properties.should eq({"bar", "1.0"})

      File.write("shard.yml", "name: # comment\nversion: # comment")
      ProjectInfo.read_shard_properties.should eq({nil, nil})
    end
  end
end
