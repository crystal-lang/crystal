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
    end
  end
end
