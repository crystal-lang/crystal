require "spec"
require "crystal/project/path_dependency"

module Crystal
  describe "PathDependency" do
    describe "#initialize" do
      it "uses the directory's name as the dependency name" do
        dependency = PathDependency.new("../path")

        dependency.name.should eq("path")
      end

      it "customizes path dependency name" do
        dependency = PathDependency.new("../path", "name")

        dependency.name.should eq("name")
      end

      %w(crystal_repo crystal-repo repo.cr repo_crystal repo-crystal).each do |repo_name|
        it "guesses name from project name like #{repo_name}" do
          dependency = PathDependency.new("owner/#{repo_name}")

          dependency.name.should eq("repo")
        end

        it "doesn't guess name from project name when specifying name" do
          dependency = PathDependency.new("owner/#{repo_name}", "name")

          dependency.name.should eq("name")
        end
      end
    end
  end
end
