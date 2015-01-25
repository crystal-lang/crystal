require "spec"
require "crystal/project"

module Crystal
  describe "Project" do
    describe "dsl" do
      it "adds GitHub dependency" do
        project = Project.new
        project.eval do
          deps do
            github "owner/repo"
          end
        end
        project.dependencies.length.should eq(1)
        project.dependencies[0].should be_a(GitHubDependency)
      end

      it "adds local dependencies" do
        project = Project.new
        project.eval do
          deps do
            path "../path"
          end
        end

        project.dependencies.length.should eq(1)
        project.dependencies[0].should be_a(PathDependency)
      end
    end
  end
end
