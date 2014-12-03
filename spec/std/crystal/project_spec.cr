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
        project.dependencies[0].name.should eq("repo")
      end

      it "customize GitHub dependency name" do
        project = Project.new
        project.eval do
          deps do
            github "owner/repo", name: "name"
          end
        end
        project.dependencies[0].name.should eq("name")
      end

      it "raises error with invalid GitHub project definition" do
        project = Project.new
        expect_raises ProjectError, /Invalid GitHub repository definition: invalid-repo/ do
          project.eval do
            deps do
              github "invalid-repo"
            end
          end
        end
      end

      %w(crystal_repo crystal-repo repo.cr repo_crystal repo-crystal).each do |repo_name|
        it "guesses name from project name like #{repo_name}" do
          project = Project.new
          project.eval do
            deps do
              github "owner/#{repo_name}"
            end
          end
          project.dependencies[0].name.should eq("repo")
        end

        it "doesn't guess name from project name when specifying name" do
          project = Project.new
          project.eval do
            deps do
              github "owner/#{repo_name}", name: "name"
            end
          end
          project.dependencies[0].name.should eq("name")
        end
      end
    end
  end
end
