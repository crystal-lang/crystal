require "../spec_helper"
require "../../support/time"

private def assert_tz_boundaries(tz : String, t0 : Time, t1 : Time, t2 : Time, t3 : Time, *, file = __FILE__, line = __LINE__)
  location = Time::Location.posix_tz("Local", tz)
  std_zone = location.zones.find(&.dst?.!).should_not be_nil, file: file, line: line
  dst_zone = location.zones.find(&.dst?).should_not be_nil, file: file, line: line
  t0, t1, t2, t3 = t0.to_unix, t1.to_unix, t2.to_unix, t3.to_unix

  location.lookup_with_boundaries(t1 - 1).should eq({std_zone, {t0, t1}}), file: file, line: line
  location.lookup_with_boundaries(t1).should eq({dst_zone, {t1, t2}}), file: file, line: line
  location.lookup_with_boundaries(t1 + (t2 - t1) // 2).should eq({dst_zone, {t1, t2}}), file: file, line: line
  location.lookup_with_boundaries(t2 - 1).should eq({dst_zone, {t1, t2}}), file: file, line: line
  location.lookup_with_boundaries(t2).should eq({std_zone, {t2, t3}}), file: file, line: line
end

private def assert_tz_raises(str, *, file = __FILE__, line = __LINE__)
  expect_raises(ArgumentError, "Invalid TZ string: #{str}", file: file, line: line) do
    Time::Location.posix_tz("", str)
  end
end

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
          Location.load("Etc/UTC").should eq Location::UTC
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

      it "with POSIX TZ string" do
        with_tz("EST5EDT,M3.2.0,M11.1.0") do
          location = Location.load_local
          location.name.should eq("Local")
          location.zones.should eq [
            Location::Zone.new("EST", -18000, false),
            Location::Zone.new("EDT", -14400, true),
          ]
          location.transitions.should be_empty
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
            std_zone = Time::Location::Zone.new("CET", 3600, false)
            dst_zone = Time::Location::Zone.new("CEST", 7200, true)
            location.zones.should eq [std_zone, dst_zone]

            location.lookup(Time.utc(2000, 10, 29, 0, 59, 59)).should eq(dst_zone)
            location.lookup(Time.utc(2000, 10, 29, 1, 0, 0)).should eq(std_zone)
            location.lookup(Time.utc(2001, 3, 25, 0, 59, 59)).should eq(std_zone)
            location.lookup(Time.utc(2001, 3, 25, 1, 0, 0)).should eq(dst_zone)

            location.lookup(Time.utc(3000, 10, 26, 0, 59, 59)).should eq(dst_zone)
            location.lookup(Time.utc(3000, 10, 26, 1, 0, 0)).should eq(std_zone)
            location.lookup(Time.utc(3001, 3, 29, 0, 59, 59)).should eq(std_zone)
            location.lookup(Time.utc(3001, 3, 29, 1, 0, 0)).should eq(dst_zone)
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

      it "exactly 24 hours" do
        location = Location.fixed 86400
        location.name.should eq "+24:00"
        location.zones.first.offset.should eq 86400

        location = Location.fixed -86400
        location.name.should eq "-24:00"
        location.zones.first.offset.should eq -86400
      end

      it "raises if offset to large" do
        expect_raises(InvalidTimezoneOffsetError, "93600") do
          Location.fixed(93600)
        end
        expect_raises(InvalidTimezoneOffsetError, "-90000") do
          Location.fixed(-90000)
        end
      end
    end

    describe ".tz" do
      it "parses string with standard time only" do
        location = Location.posix_tz("America/New_York", "EST5")
        location.name.should eq("America/New_York")
        location.zones.should eq [
          Location::Zone.new("EST", -18000, false),
        ]
        location.transitions.should be_empty
      end

      it "parses string with both standard time and DST" do
        location = Location.posix_tz("America/New_York", "EST5EDT,M3.2.0,M11.1.0")
        location.name.should eq("America/New_York")
        location.zones.should eq [
          Location::Zone.new("EST", -18000, false),
          Location::Zone.new("EDT", -14400, true),
        ]
        location.transitions.should be_empty

        location = Location.posix_tz("America/New_York", "EST5EDT-24:59:59,M3.2.0,M11.1.0")
        location.name.should eq("America/New_York")
        location.zones.should eq [
          Location::Zone.new("EST", -18000, false),
          Location::Zone.new("EDT", 89999, true),
        ]
        location.transitions.should be_empty

        location = Location.posix_tz("America/New_York", "EST-24:59:59EDT,M3.2.0,M11.1.0")
        location.name.should eq("America/New_York")
        location.zones.should eq [
          Location::Zone.new("EST", 89999, false),
          Location::Zone.new("EDT", 93599, true),
        ]
        location.transitions.should be_empty
      end

      it "parses string with all-year DST" do
        location = Location.posix_tz("America/New_York", "EST5EDT,0/0,J365/25")
        location.name.should eq("America/New_York")
        location.zones.should eq [
          Location::Zone.new("EDT", -14400, true),
        ]
        location.transitions.should be_empty

        location = Location.posix_tz("America/New_York", "XXX-6EDT-4:30:10,J1/0,J365/22:30:10")
        location.name.should eq("America/New_York")
        location.zones.should eq [
          Location::Zone.new("EDT", 16210, true),
        ]
        location.transitions.should be_empty
      end

      it "errors on invalid TZ strings" do
        # std
        assert_tz_raises ""
        assert_tz_raises "G"
        assert_tz_raises "GM"
        assert_tz_raises "<>"
        assert_tz_raises "<G>"
        assert_tz_raises "<GM>"
        assert_tz_raises "<GMT"
        assert_tz_raises "012"
        assert_tz_raises "+00"
        assert_tz_raises "-00"
        assert_tz_raises "<$aa>"
        assert_tz_raises "?"
        assert_tz_raises ":foobar"
        assert_tz_raises "/foo/bar"
        assert_tz_raises "Europe/Berlin"

        # std offset
        assert_tz_raises "EST"
        assert_tz_raises "EST "
        assert_tz_raises "EST 5"
        assert_tz_raises "EST25"
        assert_tz_raises "EST123"
        assert_tz_raises "EST00123"
        assert_tz_raises "EST-25"
        assert_tz_raises "EST-123"
        assert_tz_raises "EST-00123"
        assert_tz_raises "EST4:"
        assert_tz_raises "EST4:60"
        assert_tz_raises "EST4:+30"
        assert_tz_raises "EST4:-01"
        assert_tz_raises "EST4:20:"
        assert_tz_raises "EST4:20:60"
        assert_tz_raises "EST4:20:+30"
        assert_tz_raises "EST4:20:-01"

        # dst
        assert_tz_raises "EST5 "
        assert_tz_raises "EST5G"
        assert_tz_raises "EST5GM"
        assert_tz_raises "EST5<>"
        assert_tz_raises "EST5<GM>"
        assert_tz_raises "EST5<GMT"
        assert_tz_raises "EST5<$aa>"
        assert_tz_raises "EST5+00"
        assert_tz_raises "EST5-00"

        # dst offset
        assert_tz_raises "EST5EDT4:"
        assert_tz_raises "EST5EDT4:60"
        assert_tz_raises "EST5EDT4:+30"
        assert_tz_raises "EST5EDT4:-01"
        assert_tz_raises "EST5EDT4:20:"
        assert_tz_raises "EST5EDT4:20:60"
        assert_tz_raises "EST5EDT4:20:+30"
        assert_tz_raises "EST5EDT4:20:-01"

        # start
        assert_tz_raises "EST5EDT"
        assert_tz_raises "EST5EDT,"
        assert_tz_raises "EST5EDT,A"
        assert_tz_raises "EST5EDT,J0"
        assert_tz_raises "EST5EDT,J366"
        assert_tz_raises "EST5EDT,-1"
        assert_tz_raises "EST5EDT,366"
        assert_tz_raises "EST5EDT,M3"
        assert_tz_raises "EST5EDT,M3."
        assert_tz_raises "EST5EDT,M3.2"
        assert_tz_raises "EST5EDT,M3.2."
        assert_tz_raises "EST5EDT,M0.2.0"
        assert_tz_raises "EST5EDT,M13.2.0"
        assert_tz_raises "EST5EDT,M3.0.0"
        assert_tz_raises "EST5EDT,M3.6.0"
        assert_tz_raises "EST5EDT,M3.2.-1"
        assert_tz_raises "EST5EDT,M3.2.7"
        assert_tz_raises "EST5EDT,M3.2.0/"
        assert_tz_raises "EST5EDT,M3.2.0/168"
        assert_tz_raises "EST5EDT,M3.2.0/-168"

        # end
        assert_tz_raises "EST5EDT,M3.2.0"
        assert_tz_raises "EST5EDT,M3.2.0,"
        assert_tz_raises "EST5EDT,M3.2.0,A"
        assert_tz_raises "EST5EDT,M3.2.0,J0"
        assert_tz_raises "EST5EDT,M3.2.0,J366"
        assert_tz_raises "EST5EDT,M3.2.0,-1"
        assert_tz_raises "EST5EDT,M3.2.0,366"
        assert_tz_raises "EST5EDT,M3.2.0,M11"
        assert_tz_raises "EST5EDT,M3.2.0,M11."
        assert_tz_raises "EST5EDT,M3.2.0,M11.1"
        assert_tz_raises "EST5EDT,M3.2.0,M11.1."
        assert_tz_raises "EST5EDT,M3.2.0,M0.1.0"
        assert_tz_raises "EST5EDT,M3.2.0,M13.1.0"
        assert_tz_raises "EST5EDT,M3.2.0,M11.0.0"
        assert_tz_raises "EST5EDT,M3.2.0,M11.6.0"
        assert_tz_raises "EST5EDT,M3.2.0,M11.1.-1"
        assert_tz_raises "EST5EDT,M3.2.0,M11.1.7"
        assert_tz_raises "EST5EDT,M3.2.0,M11.1.0/"
        assert_tz_raises "EST5EDT,M3.2.0,M11.1.0/168"
        assert_tz_raises "EST5EDT,M3.2.0,M11.1.0/-168"

        # trailing characters
        assert_tz_raises "EST5EDT,M3.2.0,M11.1.0 "
        assert_tz_raises "EST5EDT,M3.2.0/2,M11.1.0/2 "
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

      context "TZ string" do
        it "looks up location with standard time only" do
          location = Location.posix_tz("Local", "EST5")
          zone, range = location.lookup_with_boundaries(Time.utc(2025, 1, 1, 22, 6, 12).to_unix)
          zone.should eq(Zone.new("EST", -18000, false))
          range.should eq({Int64::MIN, Int64::MAX})
        end

        it "looks up location with all-year DST" do
          location = Location.posix_tz("Local", "EST5EDT4,0/0,J365/25")
          zone, range = location.lookup_with_boundaries(Time.utc(2025, 1, 1, 22, 6, 12).to_unix)
          zone.should eq(Zone.new("EDT", -14400, true))
          range.should eq({Int64::MIN, Int64::MAX})
        end

        context "transition dates" do
          it "supports one-based ordinal days" do
            assert_tz_boundaries "EST5EDT4,J1/2,J365/2",
              Time.utc(2025, 12, 31, 6, 0, 0), Time.utc(2026, 1, 1, 7, 0, 0),
              Time.utc(2026, 12, 31, 6, 0, 0), Time.utc(2027, 1, 1, 7, 0, 0)

            assert_tz_boundaries "EST5EDT4,J1/2,J365/2",
              Time.utc(2027, 12, 31, 6, 0, 0), Time.utc(2028, 1, 1, 7, 0, 0),
              Time.utc(2028, 12, 31, 6, 0, 0), Time.utc(2029, 1, 1, 7, 0, 0)
          end

          it "excludes Feb 29 if one-based" do
            assert_tz_boundaries "EST5EDT4,J59/2,J60/2",
              Time.utc(2027, 3, 1, 6, 0, 0), Time.utc(2028, 2, 28, 7, 0, 0),
              Time.utc(2028, 3, 1, 6, 0, 0), Time.utc(2029, 2, 28, 7, 0, 0)
          end

          it "supports zero-based ordinal days" do
            assert_tz_boundaries "EST5EDT4,50/2,280/2",
              Time.utc(2025, 10, 8, 6, 0, 0), Time.utc(2026, 2, 20, 7, 0, 0),
              Time.utc(2026, 10, 8, 6, 0, 0), Time.utc(2027, 2, 20, 7, 0, 0)

            assert_tz_boundaries "EST5EDT4,50/2,280/2",
              Time.utc(2027, 10, 8, 6, 0, 0), Time.utc(2028, 2, 20, 7, 0, 0),
              Time.utc(2028, 10, 7, 6, 0, 0), Time.utc(2029, 2, 20, 7, 0, 0)
          end

          it "includes Feb 29 if zero-based" do
            assert_tz_boundaries "EST5EDT4,59/2,60/2",
              Time.utc(2027, 3, 2, 6, 0, 0), Time.utc(2028, 2, 29, 7, 0, 0),
              Time.utc(2028, 3, 1, 6, 0, 0), Time.utc(2029, 3, 1, 7, 0, 0)
          end

          it "supports month + week + day of week" do
            tz = "EST5EDT4,M3.2.0/2,M11.1.0/2"

            trans = [
              {Time.utc(2020, 11, 1, 6, 0, 0), Time.utc(2021, 3, 14, 7, 0, 0)},
              {Time.utc(2021, 11, 7, 6, 0, 0), Time.utc(2022, 3, 13, 7, 0, 0)},
              {Time.utc(2022, 11, 6, 6, 0, 0), Time.utc(2023, 3, 12, 7, 0, 0)},
              {Time.utc(2023, 11, 5, 6, 0, 0), Time.utc(2024, 3, 10, 7, 0, 0)},
              {Time.utc(2024, 11, 3, 6, 0, 0), Time.utc(2025, 3, 9, 7, 0, 0)},
              {Time.utc(2025, 11, 2, 6, 0, 0), Time.utc(2026, 3, 8, 7, 0, 0)},
              {Time.utc(2026, 11, 1, 6, 0, 0), Time.utc(2027, 3, 14, 7, 0, 0)},
              {Time.utc(2027, 11, 7, 6, 0, 0), Time.utc(2028, 3, 12, 7, 0, 0)},
              {Time.utc(2028, 11, 5, 6, 0, 0), Time.utc(2029, 3, 11, 7, 0, 0)},
            ]

            trans.each_cons_pair do |(t0, t1), (t2, t3)|
              assert_tz_boundaries(tz, t0, t1, t2, t3)
            end
          end

          it "handles time zone differences other than 1 hour" do
            assert_tz_boundaries "EST4:30EDT-1:23:45,M3.2.0,M11.1.0",
              Time.utc(2024, 11, 3, 0, 36, 15), Time.utc(2025, 3, 9, 6, 30, 0),
              Time.utc(2025, 11, 2, 0, 36, 15), Time.utc(2026, 3, 8, 6, 30, 0)
          end

          it "defaults transition times to 02:00:00 local time" do
            assert_tz_boundaries "EST5EDT,M3.2.0,M11.1.0",
              Time.utc(2024, 11, 3, 6, 0, 0), Time.utc(2025, 3, 9, 7, 0, 0),
              Time.utc(2025, 11, 2, 6, 0, 0), Time.utc(2026, 3, 8, 7, 0, 0)
          end

          it "supports transition times from -167 to 167 hours" do
            assert_tz_boundaries "EST5EDT,M3.2.0/-167,M11.1.0/167",
              Time.utc(2024, 11, 10, 3, 0, 0), Time.utc(2025, 3, 2, 6, 0, 0),
              Time.utc(2025, 11, 9, 3, 0, 0), Time.utc(2026, 3, 1, 6, 0, 0)
          end

          it "handles years beginning and ending in DST" do
            tz = "AEST-10AEDT,M10.1.0,M4.1.0/3"

            trans = [
              {Time.utc(2020, 4, 4, 16, 0, 0), Time.utc(2020, 10, 3, 16, 0, 0)},
              {Time.utc(2021, 4, 3, 16, 0, 0), Time.utc(2021, 10, 2, 16, 0, 0)},
              {Time.utc(2022, 4, 2, 16, 0, 0), Time.utc(2022, 10, 1, 16, 0, 0)},
              {Time.utc(2023, 4, 1, 16, 0, 0), Time.utc(2023, 9, 30, 16, 0, 0)},
              {Time.utc(2024, 4, 6, 16, 0, 0), Time.utc(2024, 10, 5, 16, 0, 0)},
              {Time.utc(2025, 4, 5, 16, 0, 0), Time.utc(2025, 10, 4, 16, 0, 0)},
              {Time.utc(2026, 4, 4, 16, 0, 0), Time.utc(2026, 10, 3, 16, 0, 0)},
              {Time.utc(2027, 4, 3, 16, 0, 0), Time.utc(2027, 10, 2, 16, 0, 0)},
              {Time.utc(2028, 4, 1, 16, 0, 0), Time.utc(2028, 9, 30, 16, 0, 0)},
              {Time.utc(2029, 3, 31, 16, 0, 0), Time.utc(2029, 10, 6, 16, 0, 0)},
            ]

            trans.each_cons_pair do |(t0, t1), (t2, t3)|
              assert_tz_boundaries(tz, t0, t1, t2, t3)
            end
          end

          it "handles very distant years" do
            assert_tz_boundaries "EST5EDT4,M3.2.0/2,M11.1.0/2",
              Time.utc(1583, 11, 6, 6, 0, 0), Time.utc(1584, 3, 11, 7, 0, 0),
              Time.utc(1584, 11, 4, 6, 0, 0), Time.utc(1585, 3, 10, 7, 0, 0)

            assert_tz_boundaries "EST5EDT4,M3.2.0/2,M11.1.0/2",
              Time.utc(3332, 11, 2, 6, 0, 0), Time.utc(3333, 3, 8, 7, 0, 0),
              Time.utc(3333, 11, 1, 6, 0, 0), Time.utc(3334, 3, 14, 7, 0, 0)
          end
        end
      end

      pending "zoneinfo + POSIX TZ string"
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
