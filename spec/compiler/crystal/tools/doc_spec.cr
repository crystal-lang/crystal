require "../../../spec_helper"
require "../../../support/tempfile"

private def assert_matches_pattern(url, **options)
  match = Crystal::Doc::Generator::GIT_REMOTE_PATTERNS.each_key.compact_map(&.match(url)).first?
  if match
    options.each { |k, v| match[k.to_s].should eq(v) }
  end
end

describe Crystal::Doc::Generator do
  describe "GIT_REMOTE_PATTERNS" do
    it "matches github repos" do
      assert_matches_pattern "https://www.github.com/foo/bar", user: "foo", repo: "bar"
      assert_matches_pattern "http://www.github.com/foo/bar", user: "foo", repo: "bar"
      assert_matches_pattern "http://github.com/foo/bar", user: "foo", repo: "bar"

      assert_matches_pattern "https://github.com/foo/bar", user: "foo", repo: "bar"
      assert_matches_pattern "https://github.com/foo/bar.git", user: "foo", repo: "bar"
      assert_matches_pattern "https://github.com/foo/bar.cr", user: "foo", repo: "bar.cr"
      assert_matches_pattern "https://github.com/foo/bar.cr.git", user: "foo", repo: "bar.cr"

      assert_matches_pattern "origin\thttps://github.com/foo/bar.cr.git (fetch)\n", user: "foo", repo: "bar.cr"
      assert_matches_pattern "origin\tgit@github.com/foo/bar.cr.git (fetch)\n", user: "foo", repo: "bar.cr"

      assert_matches_pattern "https://github.com/fOO-Bar/w00den-baRK.ab.cd", user: "fOO-Bar", repo: "w00den-baRK.ab.cd"
      assert_matches_pattern "https://github.com/fOO-Bar/w00den-baRK.ab.cd.git", user: "fOO-Bar", repo: "w00den-baRK.ab.cd"
      assert_matches_pattern "https://github.com/foo_bar/_baz-buzz.cx", user: "foo_bar", repo: "_baz-buzz.cx"
    end

    it "matches gitlab repos" do
      assert_matches_pattern "https://www.gitlab.com/foo/bar", user: "foo", repo: "bar"
      assert_matches_pattern "http://www.gitlab.com/foo/bar", user: "foo", repo: "bar"
      assert_matches_pattern "http://gitlab.com/foo/bar", user: "foo", repo: "bar"

      assert_matches_pattern "https://gitlab.com/foo/bar", user: "foo", repo: "bar"
      assert_matches_pattern "https://gitlab.com/foo/bar.git", user: "foo", repo: "bar"
      assert_matches_pattern "https://gitlab.com/foo/bar.cr", user: "foo", repo: "bar.cr"
      assert_matches_pattern "https://gitlab.com/foo/bar.cr.git", user: "foo", repo: "bar.cr"

      assert_matches_pattern "origin\thttps://gitlab.com/foo/bar.cr.git (fetch)\n", user: "foo", repo: "bar.cr"
      assert_matches_pattern "origin\tgit@gitlab.com/foo/bar.cr.git (fetch)\n", user: "foo", repo: "bar.cr"

      assert_matches_pattern "https://gitlab.com/fOO-Bar/w00den-baRK.ab.cd", user: "fOO-Bar", repo: "w00den-baRK.ab.cd"
      assert_matches_pattern "https://gitlab.com/fOO-Bar/w00den-baRK.ab.cd.git", user: "fOO-Bar", repo: "w00den-baRK.ab.cd"
      assert_matches_pattern "https://gitlab.com/foo_bar/_baz-buzz.cx", user: "foo_bar", repo: "_baz-buzz.cx"
    end
  end

  describe ".anchor_link" do
    it "generates the correct anchor link" do
      Crystal::Doc.anchor_link("anchor").should eq(
        <<-ANCHOR
        <a id="anchor" class="anchor" href="#anchor">
          <svg class="octicon-link" aria-hidden="true">
            <use href="#octicon-link"/>
          </svg>
        </a>
        ANCHOR
      )
    end
  end
end

describe Crystal::Doc::ProjectInfo do
  it "find_default_version" do
    with_tempfile("docs-git-version") do |tempdir|
      Dir.mkdir tempdir
      Dir.cd(tempdir) do
        # Non-git directory
        Crystal::Doc::ProjectInfo.find_default_version.should be_nil

        `git init`
        Crystal::Doc::ProjectInfo.find_default_version.should be_nil

        File.write("file.txt", "foo")
        `git add file.txt`
        `git commit -m 'Initial commit' --no-gpg-sign`
        Crystal::Doc::ProjectInfo.find_default_version.should be_nil

        `git tag v0.1.0`
        `git tag --list`
        `git log`
        Crystal::Doc::ProjectInfo.find_default_version.should eq "v0.1.0"

        File.write("file.txt", "bar")
        Crystal::Doc::ProjectInfo.find_default_version.should be_nil

        `git add file.txt`
        Crystal::Doc::ProjectInfo.find_default_version.should be_nil

        `git reset --hard v0.1.0`
        Crystal::Doc::ProjectInfo.find_default_version.should eq "v0.1.0"

        `git tag v0.2.0`
        Crystal::Doc::ProjectInfo.find_default_version.should be_nil
      end
    end
  end
end
