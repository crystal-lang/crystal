require "../../../../spec_helper"
require "../../../../support/tempfile"

private alias ProjectInfo = Crystal::Doc::ProjectInfo

private def run_git(command)
  Process.run(%(git -c user.email="" -c user.name="spec" #{command}), shell: true)
rescue IO::Error
  pending! "Git is not available"
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
      assert_with_defaults(ProjectInfo.new(nil, nil), ProjectInfo.new(nil, nil, refname: nil))
      assert_with_defaults(ProjectInfo.new("foo", "1.0"), ProjectInfo.new("foo", "1.0", refname: nil))
    end

    context "with shard.yml" do
      before_each do
        File.write("shard.yml", "name: foo\nversion: 1.0")
      end

      it "git missing" do
        Crystal::Git.executable = "git-missing-executable"

        assert_with_defaults(ProjectInfo.new(nil, nil), ProjectInfo.new("foo", "1.0", refname: nil))
        assert_with_defaults(ProjectInfo.new("bar", "2.0"), ProjectInfo.new("bar", "2.0", refname: nil))
        assert_with_defaults(ProjectInfo.new(nil, "2.0"), ProjectInfo.new("foo", "2.0", refname: nil))
      ensure
        Crystal::Git.executable = "git"
      end

      it "not in a git folder" do
        assert_with_defaults(ProjectInfo.new(nil, nil), ProjectInfo.new("foo", "1.0", refname: nil))
        assert_with_defaults(ProjectInfo.new("bar", "2.0"), ProjectInfo.new("bar", "2.0", refname: nil))
        assert_with_defaults(ProjectInfo.new(nil, "2.0"), ProjectInfo.new("foo", "2.0", refname: nil))
      end

      it "git but no commit" do
        run_git "init"

        assert_with_defaults(ProjectInfo.new(nil, nil), ProjectInfo.new("foo", "1.0", refname: nil))
        assert_with_defaults(ProjectInfo.new("bar", "2.0"), ProjectInfo.new("bar", "2.0", refname: nil))
        assert_with_defaults(ProjectInfo.new(nil, "2.0"), ProjectInfo.new("foo", "2.0", refname: nil))
      end

      it "git tagged version" do
        run_git "init"
        run_git "add shard.yml"
        run_git "commit -m \"Initial commit\" --no-gpg-sign"
        run_git "tag v3.0"

        assert_with_defaults(ProjectInfo.new(nil, nil), ProjectInfo.new("foo", "3.0", refname: "v3.0"))
        assert_with_defaults(ProjectInfo.new("bar", "2.0"), ProjectInfo.new("bar", "2.0", refname: "v3.0"))
        assert_with_defaults(ProjectInfo.new("bar", "2.0", refname: "12345"), ProjectInfo.new("bar", "2.0", refname: "12345"))
      end

      it "git tagged version dirty" do
        run_git "init"
        run_git "add shard.yml"
        run_git "commit -m \"Initial commit\" --no-gpg-sign"
        run_git "tag v3.0"
        File.write("shard.yml", "\n", mode: "a")

        assert_with_defaults(ProjectInfo.new(nil, nil), ProjectInfo.new("foo", "3.0-dev", refname: nil))
        assert_with_defaults(ProjectInfo.new(nil, "1.1"), ProjectInfo.new("foo", "1.1", refname: nil))
        assert_with_defaults(ProjectInfo.new("bar", "2.0"), ProjectInfo.new("bar", "2.0", refname: nil))
      end

      it "git untracked file doesn't prevent detection" do
        run_git "init"
        run_git "add shard.yml"
        run_git "commit -m \"Initial commit\" --no-gpg-sign"
        run_git "tag v3.0"
        File.write("foo.txt", "bar")

        assert_with_defaults(ProjectInfo.new(nil, nil), ProjectInfo.new("foo", "3.0", refname: "v3.0"))
      end

      it "git non-tagged commit" do
        run_git "init"
        run_git "checkout -B master"
        run_git "add shard.yml"
        run_git "commit -m \"Initial commit\" --no-gpg-sign"
        commit_sha = `git rev-parse HEAD`.chomp

        assert_with_defaults(ProjectInfo.new(nil, nil), ProjectInfo.new("foo", "master", refname: commit_sha))
        assert_with_defaults(ProjectInfo.new(nil, "1.1"), ProjectInfo.new("foo", "1.1", refname: commit_sha))
        assert_with_defaults(ProjectInfo.new("bar", "2.0"), ProjectInfo.new("bar", "2.0", refname: commit_sha))
        assert_with_defaults(ProjectInfo.new("bar", "2.0", refname: "12345"), ProjectInfo.new("bar", "2.0", refname: "12345"))
      end

      it "git non-tagged commit dirty" do
        run_git "init"
        run_git "checkout -B master"
        run_git "add shard.yml"
        run_git "commit -m \"Initial commit\" --no-gpg-sign"
        File.write("shard.yml", "\n", mode: "a")

        assert_with_defaults(ProjectInfo.new(nil, nil), ProjectInfo.new("foo", "master-dev", refname: nil))
        assert_with_defaults(ProjectInfo.new(nil, "1.1"), ProjectInfo.new("foo", "1.1", refname: nil))
        assert_with_defaults(ProjectInfo.new("bar", "2.0"), ProjectInfo.new("bar", "2.0", refname: nil))
      end

      it "git with remote" do
        run_git "init"
        run_git "remote add origin git@github.com:foo/bar"

        url_pattern = "https://github.com/foo/bar/blob/%{refname}/%{path}#L%{line}"
        assert_with_defaults(ProjectInfo.new(nil, nil), ProjectInfo.new("foo", "1.0", refname: nil, source_url_pattern: url_pattern))
        assert_with_defaults(ProjectInfo.new("bar", "2.0"), ProjectInfo.new("bar", "2.0", refname: nil, source_url_pattern: url_pattern))
        assert_with_defaults(ProjectInfo.new(nil, "2.0"), ProjectInfo.new("foo", "2.0", refname: nil, source_url_pattern: url_pattern))
        assert_with_defaults(ProjectInfo.new(nil, "2.0", source_url_pattern: "foo_bar"), ProjectInfo.new("foo", "2.0", refname: nil, source_url_pattern: "foo_bar"))
      end
    end

    it "no shard.yml, but git tagged version" do
      File.write("foo.txt", "bar")
      run_git "init"
      run_git "add foo.txt"
      run_git "commit -m \"Remove shard.yml\" --no-gpg-sign"
      run_git "tag v4.0"

      assert_with_defaults(ProjectInfo.new(nil, nil), ProjectInfo.new(nil, "4.0", refname: "v4.0"))
      assert_with_defaults(ProjectInfo.new("foo", nil), ProjectInfo.new("foo", "4.0", refname: "v4.0"))
      assert_with_defaults(ProjectInfo.new("bar", "2.0"), ProjectInfo.new("bar", "2.0", refname: "v4.0"))
      assert_with_defaults(ProjectInfo.new("bar", "2.0", refname: "12345"), ProjectInfo.new("bar", "2.0", refname: "12345"))
    end
  end

  it ".find_git_version" do
    # Non-git directory
    ProjectInfo.find_git_version.should be_nil

    # Empty git directory
    run_git "init"
    run_git "checkout -B master"
    ProjectInfo.find_git_version.should be_nil

    # Non-tagged commit
    File.write("file.txt", "foo")
    run_git "add file.txt"
    run_git "commit -m \"Initial commit\" --no-gpg-sign"
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

  describe ".git_remote" do
    it "no git workdir" do
      ProjectInfo.git_remote.should be_nil
    end

    it "no remote" do
      run_git "init"
      ProjectInfo.git_remote.should be_nil
    end

    it "simple origin" do
      run_git "init"
      run_git "remote add origin https://example.com/foo.git"
      ProjectInfo.git_remote.should eq "https://example.com/foo.git"
    end

    it "origin plus other" do
      run_git "init"
      run_git "remote add bar https://example.com/bar.git"
      run_git "remote add origin https://example.com/foo.git"
      run_git "remote add baz https://example.com/baz.git"
      `git remote -v`
      ProjectInfo.git_remote.should eq "https://example.com/foo.git"
    end

    it "no origin remote" do
      run_git "init"
      run_git "remote add bar https://example.com/bar.git"
      run_git "remote add baz https://example.com/baz.git"
      `git remote -v`
      ProjectInfo.git_remote.should eq "https://example.com/bar.git"
    end
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

  it ".find_source_url_pattern" do
    ProjectInfo.find_source_url_pattern("no a uri").should be_nil
    ProjectInfo.find_source_url_pattern("git@example.com:foo/bar").should be_nil
    ProjectInfo.find_source_url_pattern("http://example.com/foo/bar").should be_nil

    ProjectInfo.find_source_url_pattern("git@github.com:foo/bar/").should eq "https://github.com/foo/bar/blob/%{refname}/%{path}#L%{line}"
    ProjectInfo.find_source_url_pattern("git@github.com:foo/bar.git").should eq "https://github.com/foo/bar/blob/%{refname}/%{path}#L%{line}"

    ProjectInfo.find_source_url_pattern("git@github.com:foo/bar").should eq "https://github.com/foo/bar/blob/%{refname}/%{path}#L%{line}"
    ProjectInfo.find_source_url_pattern("http://github.com/foo/bar").should eq "https://github.com/foo/bar/blob/%{refname}/%{path}#L%{line}"
    ProjectInfo.find_source_url_pattern("https://github.com/foo/bar").should eq "https://github.com/foo/bar/blob/%{refname}/%{path}#L%{line}"
    ProjectInfo.find_source_url_pattern("http://www.github.com/foo/bar").should eq "https://github.com/foo/bar/blob/%{refname}/%{path}#L%{line}"
    ProjectInfo.find_source_url_pattern("https://www.github.com/foo/bar").should eq "https://github.com/foo/bar/blob/%{refname}/%{path}#L%{line}"

    ProjectInfo.find_source_url_pattern("https://github.com/foo/bar.git").should eq "https://github.com/foo/bar/blob/%{refname}/%{path}#L%{line}"
    ProjectInfo.find_source_url_pattern("https://github.com/foo/bar.cr").should eq "https://github.com/foo/bar.cr/blob/%{refname}/%{path}#L%{line}"
    ProjectInfo.find_source_url_pattern("https://github.com/foo/bar.cr.git").should eq "https://github.com/foo/bar.cr/blob/%{refname}/%{path}#L%{line}"

    ProjectInfo.find_source_url_pattern("git@gitlab.com:foo/bar").should eq "https://gitlab.com/foo/bar/blob/%{refname}/%{path}#L%{line}"
    ProjectInfo.find_source_url_pattern("http://gitlab.com/foo/bar").should eq "https://gitlab.com/foo/bar/blob/%{refname}/%{path}#L%{line}"
    ProjectInfo.find_source_url_pattern("http://gitlab.com/foo/bar.git").should eq "https://gitlab.com/foo/bar/blob/%{refname}/%{path}#L%{line}"

    ProjectInfo.find_source_url_pattern("git@bitbucket.com:foo/bar").should eq "https://bitbucket.com/foo/bar/src/%{refname}/%{path}#%{filename}-%{line}"
    ProjectInfo.find_source_url_pattern("http://bitbucket.com/foo/bar").should eq "https://bitbucket.com/foo/bar/src/%{refname}/%{path}#%{filename}-%{line}"
    ProjectInfo.find_source_url_pattern("http://bitbucket.com/foo/bar.git").should eq "https://bitbucket.com/foo/bar/src/%{refname}/%{path}#%{filename}-%{line}"

    ProjectInfo.find_source_url_pattern("git@git.sr.ht:~foo/bar").should eq "https://git.sr.ht/~foo/bar/tree/%{refname}/%{path}#L%{line}"
    ProjectInfo.find_source_url_pattern("http://git.sr.ht/~foo/bar").should eq "https://git.sr.ht/~foo/bar/tree/%{refname}/%{path}#L%{line}"
    ProjectInfo.find_source_url_pattern("http://git.sr.ht/~foo/bar.git").should eq "https://git.sr.ht/~foo/bar.git/tree/%{refname}/%{path}#L%{line}"
  end

  describe "#source_url" do
    it "fails if refname is missing" do
      location = Crystal::Doc::RelativeLocation.new("foo/bar.baz", 42)
      info = ProjectInfo.new("test", "v1.0", refname: nil, source_url_pattern: "http://git.example.com/test.git/src/%{refname}/%{path}#L%{line}")
      info.source_url(location).should be_nil
    end

    it "fails if pattern is missing" do
      location = Crystal::Doc::RelativeLocation.new("foo/bar.baz", 42)
      info = ProjectInfo.new("test", "v1.0", refname: "master")
      info.source_url(location).should be_nil
    end

    it "builds url" do
      info = ProjectInfo.new("test", "v1.0", refname: "master", source_url_pattern: "http://git.example.com/test.git/src/%{refname}/%{path}#L%{line}")
      location = Crystal::Doc::RelativeLocation.new("foo/bar.baz", 42)
      info.source_url(location).should eq "http://git.example.com/test.git/src/master/foo/bar.baz#L42"
    end

    it "returns nil for empty pattern" do
      info = ProjectInfo.new("test", "v1.0", refname: "master", source_url_pattern: "")
      location = Crystal::Doc::RelativeLocation.new("foo/bar.baz", 42)
      info.source_url(location).should be_nil
    end

    it "fails if pattern is missing" do
      location = Crystal::Doc::RelativeLocation.new("foo/bar.baz", 42)
      info = ProjectInfo.new("test", "v1.0")
      info.refname = "master"
      info.source_url(location).should be_nil
    end

    it "builds url" do
      info = ProjectInfo.new("test", "v1.0")
      info.refname = "master"
      info.source_url_pattern = "http://git.example.com/test.git/src/%{refname}/%{path}#L%{line}"
      location = Crystal::Doc::RelativeLocation.new("foo/bar.baz", 42)
      info.source_url(location).should eq "http://git.example.com/test.git/src/master/foo/bar.baz#L42"
    end
  end
end
