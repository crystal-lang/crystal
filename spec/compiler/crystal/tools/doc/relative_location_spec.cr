require "../../../spec_helper"

describe Crystal::Doc::RelativeLocation do
  describe ".from" do
    it "creates from same base directory" do
      relative_location = Crystal::Doc::RelativeLocation.from(
        Location.new("/base/dir/src/foo.cr", 1, 1),
        "/base/dir/src"
      ).should_not be_nil

      relative_location.filename.should eq "foo.cr"
    end

    it "creates from a parent base directory" do
      relative_location = Crystal::Doc::RelativeLocation.from(
        Location.new("/base/dir/src/foo.cr", 1, 1),
        "/base/dir"
      ).should_not be_nil

      relative_location.filename.should eq ::Path["src", "foo.cr"].to_s
    end

    it "creates from a child base directory" do
      relative_location = Crystal::Doc::RelativeLocation.from(
        Location.new("/base/dir/src/foo.cr", 1, 1),
        "/base/dir/src/app"
      ).should_not be_nil

      relative_location.filename.should eq ::Path["..", "foo.cr"].to_s
    end
  end
end
