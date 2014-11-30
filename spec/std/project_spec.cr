require "spec"
require "project"

describe "Project" do
  describe "dsl" do
    it "adds GitHub dependency" do
      project = Project.new
      deps(project) do
        github "owner/repo"
      end
      project.dependencies.length.should eq(1)
      project.dependencies[0].should be_a(GitHubDependency)
      project.dependencies[0].name.should eq("repo")
    end

    it "customize GitHub dependency name" do
      project = Project.new
      deps(project) do
        github "owner/repo", name: "name"
      end
      project.dependencies[0].name.should eq("name")
    end

    it "raises error with invalid GitHub project definition" do
      project = Project.new
      expect_raises ProjectError, /Invalid GitHub repository definition: invalid-repo/ do
        deps(project) do
          github "invalid-repo"
        end
      end
    end
  end
end
