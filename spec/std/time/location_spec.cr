require "spec"
require "./spec_helper"

class Time::Location
  def __cached_range
    @cached_range
  end

  def __cached_zone
    @cached_zone
  end

  def __cached_zone=(zone)
    @cached_zone = zone
  end

  def self.__clear_location_cache
    @@location_cache.clear
  end

  describe Time::Location do
    describe ".load" do
      it "loads Europe/Berlin" do
        location = Location.load("Europe/Berlin")

        location.name.should eq "Europe/Berlin"
        standard_time = location.lookup(Time.new(2017, 11, 22))
        standard_time.name.should eq "CET"
        standard_time.offset.should eq 3600
        standard_time.dst?.should be_false

        summer_time = location.lookup(Time.new(2017, 10, 22))
        summer_time.name.should eq "CEST"
        summer_time.offset.should eq 7200
        summer_time.dst?.should be_true

        location.utc?.should be_false
        location.fixed?.should be_false

        with_env("TZ", nil) do
          location.local?.should be_false
        end

        with_env("TZ", "Europe/Berlin") do
          location.local?.should be_true
        end

        Location.load?("Europe/Berlin", Crystal::System::Time.zone_sources).should eq location
      end

      it "invalid timezone identifier" do
        expect_raises(InvalidLocationNameError, "Foobar/Baz") do
          Location.load("Foobar/Baz")
        end

        Location.load?("Foobar/Baz", Crystal::System::Time.zone_sources).should be_nil
      end

      it "treats UTC as special case" do
        Location.load("UTC").should eq Location::UTC
        Location.load("").should eq Location::UTC

        # Etc/UTC could be pointing to anything
        Location.load("Etc/UTC").should_not eq Location::UTC
      end

      describe "validating name" do
        it "absolute path" do
          expect_raises(InvalidLocationNameError) do
            Location.load("/America/New_York")
          end
          expect_raises(InvalidLocationNameError) do
            Location.load("\\Zulu")
          end
        end
        it "dot dot" do
          expect_raises(InvalidLocationNameError) do
            Location.load("../zoneinfo/America/New_York")
          end
          expect_raises(InvalidLocationNameError) do
            Location.load("a..")
          end
        end
      end

      context "with ZONEINFO" do
        it "loads from custom directory" do
          with_zoneinfo(File.join(__DIR__, "..", "data", "zoneinfo")) do
            location = Location.load("Foo/Bar")
            location.name.should eq "Foo/Bar"
          end
        end

        it "loads from custom zipfile" do
          with_zoneinfo(ZONEINFO_ZIP) do
            location = Location.load("Asia/Jerusalem")
            location.not_nil!.name.should eq "Asia/Jerusalem"
          end
        end

        it "raises if not available" do
          with_zoneinfo(ZONEINFO_ZIP) do
            expect_raises(InvalidLocationNameError) do
              Location.load("Foo/Bar")
            end
            Location.load?("Foo/Bar", Crystal::System::Time.zone_sources).should be_nil
          end
        end

        it "does not fall back to default sources" do
          with_zoneinfo(File.join(__DIR__, "..", "data", "zoneinfo")) do
            expect_raises(InvalidLocationNameError) do
              Location.load("Europe/Berlin")
            end
          end

          with_zoneinfo("nonexising_zipfile.zip") do
            expect_raises(InvalidLocationNameError) do
              Location.load("Europe/Berlin")
            end
          end
        end

        it "caches result" do
          with_zoneinfo do
            location = Location.load("Europe/Berlin")
            Location.load("Europe/Berlin").should be location
          end
        end

        it "loads new data if file was changed" do
          zoneinfo_path = File.join(__DIR__, "..", "data", "zoneinfo")
          with_zoneinfo(zoneinfo_path) do
            location1 = Location.load("Foo/Bar")
            File.touch(File.join(zoneinfo_path, "Foo/Bar"))
            location2 = Location.load("Foo/Bar")

            location1.should eq location2
            location1.should_not be location2
          end
        end

        it "loads new data if ZIP file was changed" do
          with_zoneinfo(ZONEINFO_ZIP) do
            location1 = Location.load("Europe/Berlin")
            File.touch(ZONEINFO_ZIP)
            location2 = Location.load("Europe/Berlin")

            location1.should eq location2
            location1.should_not be location2
          end
        end
      end
    end

    it "UTC" do
      location = Location::UTC
      location.name.should eq "UTC"

      location.utc?.should be_true
      location.fixed?.should be_true

      # this could fail if no source for localtime is available
      unless Location.local.utc?
        location.local?.should be_false
      end

      zone = location.lookup(Time.now)
      zone.name.should eq "UTC"
      zone.offset.should eq 0
      zone.dst?.should be_false
    end

    it ".local" do
      Location.local.should eq Location.load_local

      Location.local = Location::UTC
      Location.local.should be Location::UTC
    end

    it ".load_local" do
      with_env("TZ", nil) do
        Location.load_local.name.should eq "Local"
      end
      with_zoneinfo do
        with_env("TZ", "Europe/Berlin") do
          Location.load_local.name.should eq "Europe/Berlin"
        end
      end
      with_env("TZ", "") do
        Location.load_local.utc?.should be_true
      end
    end

    describe ".fixed" do
      it "accepts a name" do
        location = Location.fixed("Fixed", 1800)
        location.name.should eq "Fixed"
        location.zones.should eq [Zone.new("Fixed", 1800, false)]
        location.transitions.size.should eq 0

        location.utc?.should be_false
        location.fixed?.should be_true
        location.local?.should be_false
      end

      it "positive" do
        location = Location.fixed 8000
        location.name.should eq "+02:13"
        location.zones.first.offset.should eq 8000
      end

      it "ngeative" do
        location = Location.fixed -7539
        location.name.should eq "-02:05"
        location.zones.first.offset.should eq -7539
      end

      it "raises if offset to large" do
        expect_raises(InvalidTimezoneOffsetError, "86401") do
          Location.fixed(86401)
        end
        expect_raises(InvalidTimezoneOffsetError, "-90000") do
          Location.fixed(-90000)
        end
      end
    end

    describe "#lookup" do
      it "looks up" do
        with_zoneinfo do
          location = Location.load("Europe/Berlin")
          zone, range = location.lookup_with_boundaries(Time.utc(2017, 11, 23, 22, 6, 12).epoch)
          zone.should eq Zone.new("CET", 3600, false)
          range.should eq({1509238800_i64, 1521939600_i64})
        end
      end

      it "handles dst change" do
        with_zoneinfo do
          location = Location.load("Europe/Berlin")
          time = Time.utc(2017, 10, 29, 1, 0, 0)

          summer = location.lookup(time - 1.second)
          summer.name.should eq "CEST"
          summer.offset.should eq 2 * SECONDS_PER_HOUR
          summer.dst?.should be_true

          winter = location.lookup(time)
          winter.name.should eq "CET"
          winter.offset.should eq 1 * SECONDS_PER_HOUR
          winter.dst?.should be_false

          last_ns = location.lookup(time - 1.nanosecond)
          last_ns.name.should eq "CEST"
          last_ns.offset.should eq 2 * SECONDS_PER_HOUR
          last_ns.dst?.should be_true
        end
      end

      it "handles value after last transition" do
        with_zoneinfo do
          location = Location.load("America/Buenos_Aires")
          zone = location.lookup(Time.utc(5000, 1, 1))
          zone.name.should eq "-03"
          zone.offset.should eq -3 * 3600
        end
      end

      # Test that we get the correct results for times before the first
      # transition time. To do this we explicitly check early dates in a
      # couple of specific timezones.
      context "first zone" do
        it "PST8PDT" do
          with_zoneinfo do
            location = Location.load("PST8PDT")
            zone1 = location.lookup(-1633269601)
            zone2 = location.lookup(-1633269601 + 1)
            zone1.name.should eq "PST"
            zone1.offset.should eq -8 * SECONDS_PER_HOUR
            zone2.name.should eq "PDT"
            zone2.offset.should eq -7 * SECONDS_PER_HOUR
          end
        end

        it "Pacific/Fakaofo" do
          with_zoneinfo do
            location = Location.load("Pacific/Fakaofo")
            zone1 = location.lookup(1325242799)
            zone2 = location.lookup(1325242799 + 1)
            zone1.name.should eq "-11"
            zone1.offset.should eq -11 * SECONDS_PER_HOUR
            zone2.name.should eq "+13"
            zone2.offset.should eq 13 * SECONDS_PER_HOUR
          end
        end
      end

      it "caches last zone" do
        with_zoneinfo do
          location = Time::Location.load("Europe/Berlin")

          location.__cached_range.should eq({Int64::MIN, Int64::MIN})
          location.__cached_zone.should eq Zone.new("LMT", 3208, false)

          expected_zone = Zone.new("CET", 3600, false)

          location.lookup(Time.utc(2017, 11, 23, 22, 6, 12)).should eq expected_zone

          location.__cached_range.should eq({1509238800_i64, 1521939600_i64})
          location.__cached_zone.should eq expected_zone
        end
      end

      it "reads from cache" do
        with_zoneinfo do
          location = Location.load("Europe/Berlin")
          location.lookup(Time.utc(2017, 11, 23, 22, 6, 12)).should eq Zone.new("CET", 3600, false)
          cached_zone = Zone.new("MyZone", 1234, true)
          location.__cached_zone = cached_zone

          location.lookup(Time.utc(2017, 11, 23, 22, 6, 12)).should eq cached_zone
        end
      end
    end
  end
end
