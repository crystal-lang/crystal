require "../spec_helper"
require "../../support/time"

class Time::Location
  describe Time::Location do
    describe ".load" do
      it "loads Europe/Berlin" do
        with_zoneinfo do
          location = Location.load("Europe/Berlin")

          location.name.should eq "Europe/Berlin"
          standard_time = location.lookup(Time.utc(2017, 11, 22))
          standard_time.name.should eq "CET"
          standard_time.offset.should eq 3600
          standard_time.dst?.should be_false

          summer_time = location.lookup(Time.utc(2017, 10, 22))
          summer_time.name.should eq "CEST"
          summer_time.offset.should eq 7200
          summer_time.dst?.should be_true

          location.utc?.should be_false
          location.fixed?.should be_false

          with_tz(nil) do
            location.local?.should be_false
          end

          with_tz("Europe/Berlin") do
            location.local?.should be_true
          end

          Location.load("Europe/Berlin", {ZONEINFO_ZIP}).should eq location
        end
      end

      {% if flag?(:win32) %}
        it "maps IANA timezone identifier to Windows name (#13166)" do
          location = Location.load("Europe/Berlin")
          location.name.should eq "Europe/Berlin"
          location.utc?.should be_false
          location.fixed?.should be_false
        end
      {% end %}

      it "invalid timezone identifier" do
        with_zoneinfo(datapath("zoneinfo")) do
          expect_raises(InvalidLocationNameError, "Foobar/Baz") do
            Location.load("Foobar/Baz")
          end
        end

        Location.load?("Foobar/Baz", [datapath("zoneinfo")]).should be_nil
      end

      it "name is folder" do
        Location.load?("Foo", [datapath("zoneinfo")]).should be_nil
      end

      it "invalid zone file" do
        expect_raises(Time::Location::InvalidTZDataError) do
          Location.load?("Foo/invalid", [datapath("zoneinfo")])
        end
      end

      it "treats UTC as special case" do
        with_zoneinfo do
          Location.load("UTC").should eq Location::UTC
          Location.load("").should eq Location::UTC

          # Etc/UTC could be pointing to anything
          Location.load("Etc/UTC").should_not eq Location::UTC
        end
      end

      describe "validating name" do
        it "absolute path" do
          with_zoneinfo do
            expect_raises(InvalidLocationNameError) do
              Location.load("/America/New_York")
            end
            expect_raises(InvalidLocationNameError) do
              Location.load("\\Zulu")
            end
          end
        end
        it "dot dot" do
          with_zoneinfo do
            expect_raises(InvalidLocationNameError) do
              Location.load("../zoneinfo/America/New_York")
            end
            expect_raises(InvalidLocationNameError) do
              Location.load("a..")
            end
          end
        end
      end

      context "with ZONEINFO" do
        it "loads from custom directory" do
          with_zoneinfo(datapath("zoneinfo")) do
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
          with_zoneinfo(datapath("zoneinfo")) do
            expect_raises(InvalidLocationNameError) do
              Location.load("Europe/Berlin")
            end
          end

          with_zoneinfo("nonexistent_zipfile.zip") do
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
          zoneinfo_path = datapath("zoneinfo")
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

    describe ".load_android" do
      it "loads Europe/Berlin" do
        Location.__clear_location_cache
        location = Location.load_android("Europe/Berlin", {datapath("android_tzdata")}).should_not be_nil

        location.name.should eq "Europe/Berlin"
        standard_time = location.lookup(Time.utc(2017, 11, 22))
        standard_time.name.should eq "CET"
        standard_time.offset.should eq 3600
        standard_time.dst?.should be_false

        summer_time = location.lookup(Time.utc(2017, 10, 22))
        summer_time.name.should eq "CEST"
        summer_time.offset.should eq 7200
        summer_time.dst?.should be_true

        location.utc?.should be_false
        location.fixed?.should be_false
      end

      it "loads new data if tzdata file was changed" do
        tzdata_path = datapath("android_tzdata")
        Location.__clear_location_cache
        location1 = Location.load_android("Europe/Berlin", {tzdata_path})
        File.touch(tzdata_path)
        location2 = Location.load_android("Europe/Berlin", {tzdata_path})

        location1.should eq location2
        location1.should_not be location2
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

      zone = location.lookup(Time.utc)
      zone.name.should eq "UTC"
      zone.offset.should eq 0
      zone.dst?.should be_false
    end

    it ".local" do
      with_zoneinfo do
        Location.local.should eq Location.load_local
      end

      Location.local = Location::UTC
      Location.local.should be Location::UTC
    end

    describe ".load_local" do
      it "with unset TZ" do
        with_tz(nil) do
          # This should generally be `Local`, but if `/etc/localtime` doesn't exist,
          # `Crystal::System::Time.load_localtime` can't resolve a local time zone,
          # making the return value default to `UTC`.
          {"Local", "UTC"}.should contain Location.load_local.name
        end
      end

      it "with TZ" do
        with_zoneinfo do
          with_tz("Europe/Berlin") do
            Location.load_local.name.should eq "Europe/Berlin"
          end
        end
        with_zoneinfo(datapath("zoneinfo")) do
          with_tz("Foo/Bar") do
            Location.load_local.name.should eq "Foo/Bar"
          end
        end
      end

      it "with empty TZ" do
        with_zoneinfo do
          with_tz("") do
            Location.load_local.utc?.should be_true
          end
        end
      end

      {% if flag?(:win32) %}
        it "loads time zone information from registry" do
          info = LibC::DYNAMIC_TIME_ZONE_INFORMATION.new(
            bias: -60,
            standardBias: 0,
            daylightBias: -60,
            standardDate: LibC::SYSTEMTIME.new(wYear: 0, wMonth: 10, wDayOfWeek: 0, wDay: 5, wHour: 3, wMinute: 0, wSecond: 0, wMilliseconds: 0),
            daylightDate: LibC::SYSTEMTIME.new(wYear: 0, wMonth: 3, wDayOfWeek: 0, wDay: 5, wHour: 2, wMinute: 0, wSecond: 0, wMilliseconds: 0),
          )
          info.standardName.to_slice.copy_from "Central Europe Standard Time".to_utf16
          info.daylightName.to_slice.copy_from "Central Europe Summer Time".to_utf16
          info.timeZoneKeyName.to_slice.copy_from "Central Europe Standard Time".to_utf16

          with_system_time_zone(info) do
            location = Location.load_local
            location.zones.should eq [Time::Location::Zone.new("CET", 3600, false), Time::Location::Zone.new("CEST", 7200, true)]
          end
        end

        it "loads time zone without DST (#13502)" do
          info = LibC::DYNAMIC_TIME_ZONE_INFORMATION.new(bias: -480)
          info.standardName.to_slice.copy_from "China Standard Time".to_utf16
          info.daylightName.to_slice.copy_from "China Daylight Time".to_utf16
          info.timeZoneKeyName.to_slice.copy_from "China Standard Time".to_utf16

          with_system_time_zone(info) do
            location = Location.load_local
            location.zones.should eq [Time::Location::Zone.new("CST", 28800, false)]
          end
        end
      {% end %}
    end

    describe ".fixed" do
      it "without name" do
        location = Location.fixed -9012
        location.name.should eq "-02:30:12"
        location.zones.should eq [Zone.new(nil, -9012, false)]
        location.transitions.size.should eq 0

        location.utc?.should be_false
        location.fixed?.should be_true
        location.local?.should be_false
      end

      it "with name" do
        location = Location.fixed "Fixed", 1800
        location.name.should eq "Fixed"
        location.zones.should eq [Zone.new("Fixed", 1800, false)]
        location.transitions.size.should eq 0

        location.utc?.should be_false
        location.fixed?.should be_true
        location.local?.should be_false
      end

      it "positive" do
        location = Location.fixed 8000
        location.name.should eq "+02:13:20"
        location.zones.first.offset.should eq 8000
      end

      it "negative" do
        location = Location.fixed -7539
        location.name.should eq "-02:05:39"
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
          zone, range = location.lookup_with_boundaries(Time.utc(2017, 11, 23, 22, 6, 12).to_unix)
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

          location.@cached_range.should eq({Int64::MIN, Int64::MIN})
          location.@cached_zone.should eq Zone.new("LMT", 3208, false)

          expected_zone = Zone.new("CET", 3600, false)

          location.lookup(Time.utc(2017, 11, 23, 22, 6, 12)).should eq expected_zone

          location.@cached_range.should eq({1509238800_i64, 1521939600_i64})
          location.@cached_zone.should eq expected_zone
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

  describe Time::Location::Zone do
    it "#inspect" do
      Time::Location::Zone.new("CET", 3600, false).inspect.should eq "Time::Location::Zone(CET +01:00 (3600s) STD)"
      Time::Location::Zone.new("CEST", 7200, true).inspect.should eq "Time::Location::Zone(CEST +02:00 (7200s) DST)"
      Time::Location::Zone.new(nil, 9000, true).inspect.should eq "Time::Location::Zone(+02:30 (9000s) DST)"
      Time::Location::Zone.new(nil, 9012, true).inspect.should eq "Time::Location::Zone(+02:30:12 (9012s) DST)"
    end

    it "#name" do
      Time::Location::Zone.new("CEST", 7200, true).name.should eq "CEST"
      Time::Location::Zone.new(nil, 9000, true).name.should eq "+02:30"
    end
  end
end
