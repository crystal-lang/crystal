require "spec"
require "software_version"

private def v(string)
  SoftwareVersion.parse string
end

private def v(version : SoftwareVersion)
  version
end

# Assert that two versions are equal. Handles strings or
# SoftwareVersion instances.
private def assert_version_equal(expected, actual)
  v(actual).should eq v(expected)
  v(actual).hash.should eq(v(expected).hash), "since #{actual} == #{expected}, they must have the same hash"
end

# Refute the assumption that the two versions are equal.
private def refute_version_equal(unexpected, actual)
  v(actual).should_not eq v(unexpected)
  v(actual).hash.should_not eq(v(unexpected).hash), "since #{actual} != #{unexpected}, they must not have the same hash"
end

describe SoftwareVersion do
  it ".valid?" do
    SoftwareVersion.valid?("5.1").should be_true
    SoftwareVersion.valid?("an invalid version").should be_false
  end

  it "equals" do
    assert_version_equal "1.2", "1.2"
    assert_version_equal "1.2.b1", "1.2.b.1"
    assert_version_equal "1.0+1234", "1.0+1234"
    refute_version_equal "1.2", "1.2.0"
    refute_version_equal "1.2", "1.3"
  end

  it ".new with number" do
    assert_version_equal "1", SoftwareVersion.new(1)
    assert_version_equal "1.0", SoftwareVersion.new(1.0)
  end

  it ".new with segments" do
    SoftwareVersion.new(1).to_s.should eq "1"
    SoftwareVersion.new(1, 0).to_s.should eq "1.0"
    SoftwareVersion.new(1, 0, 0).to_s.should eq "1.0.0"
    SoftwareVersion.new(1, 0, 0, prerelease: "rc1").to_s.should eq "1.0.0-rc1"
    SoftwareVersion.new(1, 0, 0, prerelease: "rc1", metadata: "build8").to_s.should eq "1.0.0-rc1+build8"
    SoftwareVersion.new(1, prerelease: "rc1").to_s.should eq "1-rc1"
    SoftwareVersion.new(1, prerelease: "rc1", metadata: "build8").to_s.should eq "1-rc1+build8"
  end

  describe ".parse" do
    it "parses metadata" do
      SoftwareVersion.parse("1.0+1234")
    end

    it "valid values for 1.0" do
      {"1.0", "1.0 ", " 1.0 ", "1.0\n", "\n1.0\n", "1.0"}.each do |good|
        assert_version_equal "1.0", good
      end
    end

    it "invalid values" do
      invalid_versions = %w[
        junk
        1.0\n2.0
        1..2
        1.2\ 3.4
      ]

      # DON'T TOUCH THIS WITHOUT CHECKING CVE-2013-4287
      invalid_versions << "2.3422222.222.222222222.22222.ads0as.dasd0.ddd2222.2.qd3e."

      invalid_versions.each do |invalid|
        expect_raises ArgumentError, "Malformed version string #{invalid.inspect}" do
          SoftwareVersion.parse invalid
        end
        SoftwareVersion.parse?(invalid).should be_nil
      end
    end

    it "empty version" do
      ["", "   ", " "].each do |empty|
        SoftwareVersion.parse(empty).to_s.should eq "0"
      end
    end
  end

  it "#<=>" do
    # This spec has changed from Gems::Version where both where considered equal
    v("1.0").should be < v("1.0.0")

    v("1.0").should be > v("1.0.a")
    v("1.8.2").should be > v("0.0.0")
    v("1.8.2").should be > v("1.8.2.a")
    v("1.8.2.b").should be > v("1.8.2.a")
    v("1.8.2.a10").should be > v("1.8.2.a9")
    v("1.0.0+build1").should be > v("1.0.0")
    v("1.0.0+build2").should be > v("1.0.0+build1")

    v("1.2.b1").should eq v("1.2.b.1")
    v("").should eq v("0")
    v("1.2.b1").should eq v("1.2.b1")
    v("1.0a").should eq v("1.0.a")
    v("1.0a").should eq v("1.0-a")
    v("1.0.0+build1").should eq v("1.0.0+build1")

    v("1.8.2.a").should be < v("1.8.2")
    v("1.2").should be < v("1.3")
    v("0.2.0").should be < v("0.2.0.1")
    v("1.2.rc1").should be < v("1.2.rc2")
  end

  it "sort" do
    list = ["0.1.0", "0.2.0", "5.333.1", "5.2.1", "0.2", "0.2.0.1", "5.8", "0.0.0.11"].map { |v| v(v) }

    list.sort.map(&.to_s).should eq ["0.0.0.11", "0.1.0", "0.2", "0.2.0", "0.2.0.1", "5.2.1", "5.8", "5.333.1"]
  end

  it "#prerelease?" do
    v("1.2.0.a").prerelease?.should be_true
    v("1.0a").prerelease?.should be_true
    v("2.9.b").prerelease?.should be_true
    v("22.1.50.0.d").prerelease?.should be_true
    v("1.2.d.42").prerelease?.should be_true

    v("1.A").prerelease?.should be_true

    v("1-1").prerelease?.should be_true
    v("1-a").prerelease?.should be_true

    v("1.0").prerelease?.should be_false
    v("1.0.0.1").prerelease?.should be_false

    v("1.0+20190405").prerelease?.should be_false
    v("1.0+build1").prerelease?.should be_false

    v("1.2.0").prerelease?.should be_false
    v("2.9").prerelease?.should be_false
    v("22.1.50.0").prerelease?.should be_false
    v("1.0+b").prerelease?.should be_false
  end

  it "#release" do
    # Assert that *release* is the correct non-prerelease *version*.
    v("1.0").release.should eq v("1.0")
    v("1.2.0.a").release.should eq v("1.2.0")
    v("1.1.rc10").release.should eq v("1.1")
    v("1.9.3.alpha.5").release.should eq v("1.9.3")
    v("1.9.3").release.should eq v("1.9.3")
    v("0.4.0").release.should eq v("0.4.0")

    # Return release without metadata
    v("1.0+12345").release.should eq v("1.0")
    v("1.0+build1").release.should eq v("1.0")
    v("1.0-rc1+build1").release.should eq v("1.0")
    v("1.0a+build1").release.should eq v("1.0")
  end

  it "#metadata" do
    v("1.0+12345").metadata.should eq "12345"
    v("1.0+build1").metadata.should eq "build1"
    v("1.0-rc1+build1").metadata.should eq "build1"
    v("1.0a+build1").metadata.should eq "build1"
  end
end
