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
        expect(project.dependencies.length).to eq(1)
        expect(project.dependencies[0]).to be_a(GitHubDependency)
      end

      it "adds local dependencies" do
        project = Project.new
        project.eval do
          deps do
            path "../path"
          end
        end

        expect(project.dependencies.length).to eq(1)
        expect(project.dependencies[0]).to be_a(PathDependency)
      end
    end
  end
end
