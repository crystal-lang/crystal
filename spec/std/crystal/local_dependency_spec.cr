require "spec"
require "crystal/project/local_dependency"

module Crystal
  describe "LocalDependency" do
    describe "#initialize" do
      it "uses the directory's name as the dependency name" do
        dependency = LocalDependency.new("../path")

        dependency.name.should eq("path")
      end

      it "customizes local dependency name" do
        dependency = LocalDependency.new("../path", "name")

        dependency.name.should eq("name")
      end
    end
  end
end
