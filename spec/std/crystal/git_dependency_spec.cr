require "spec"
require "crystal/project/git_dependency"

module Crystal
  describe "GitDependency" do
    describe "#initialize" do
      it "uses the repository's name as the dependency name" do
        dependency = GitDependency.new("https://example.com/owner/repo")

        dependency.name.should eq("repo")
      end

      it "customizes Git dependency name" do
        dependency = GitDependency.new("https://example.com/owner/repo", "name")

        dependency.name.should eq("name")
      end

      it "raises error with invalid Git project definition" do
        expect_raises ProjectError, /Invalid Git repository definition: invalid-repo/ do
          GitDependency.new("invalid-repo")
        end
      end

      %w(crystal_repo crystal-repo repo.cr repo_crystal repo-crystal).each do |repo_name|
        it "guesses name from project name like #{repo_name}" do
          dependency = GitDependency.new("https://example.com/owner/#{repo_name}")

          dependency.name.should eq("repo")
        end

        it "doesn't guess name from project name when specifying name" do
          dependency = GitDependency.new("https://example.com/owner/#{repo_name}", "name")

          dependency.name.should eq("name")
        end
      end

      it "gets the target_dir" do
        dependency = GitDependency.new("https://example.com/owner/repo")
        dependency.target_dir.should eq(".deps/owner-repo")
      end
    end
  end
end
