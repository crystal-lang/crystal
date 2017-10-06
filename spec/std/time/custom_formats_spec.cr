require "spec"

describe Time::Format do
  describe "RFC_3339" do
    it "parses regular format" do
      time = Time.new(2016, 2, 15, kind: Time::Kind::Utc)
      Time::Format::RFC_3339.format(time).should eq "2016-02-15T00:00:00Z"
      Time::Format::RFC_3339.parse("2016-02-15T00:00:00+00:00").should eq time
      Time::Format::RFC_3339.parse("2016-02-15t00:00:00+00:00").should eq time
      Time::Format::RFC_3339.parse("2016-02-15 00:00:00+00:00").should eq time
      Time::Format::RFC_3339.parse("2016-02-15T00:00:00Z").should eq time
      Time::Format::RFC_3339.parse("2016-02-15T00:00:00.0000000+00:00").should eq time
    end
  end

  describe Time::Format::RFC_2822 do
    it "parses regular format" do
      time = Time.new(2016, 2, 15, kind: Time::Kind::Utc)
      Time::Format::RFC_2822.format(time).should eq "Mon, 15 Feb 2016 00:00:00 +0000"
      Time::Format::RFC_2822.parse("Mon, 15 Feb 2016 00:00:00 +0000").should eq time
      Time::Format::RFC_2822.parse("Mon, 15 Feb 16 00:00 UT").should eq time
      Time::Format::RFC_2822.parse(" Mon , 14 Feb 2016 20 : 00 : 00 EDT (comment)").to_utc.should eq time
    end
  end

  describe "ISO_8601_DATE" do
    it "formats default format" do
      time = Time.new(1985, 4, 12, kind: Time::Kind::Utc)
      Time::Format::ISO_8601_DATE.format(time).should eq "1985-04-12"
    end

    it "parses calendar date" do
      time = Time.new(1985, 4, 12, kind: Time::Kind::Utc)
      Time::Format::ISO_8601_DATE.parse("1985-04-12").should eq(time)
      Time::Format::ISO_8601_DATE.parse("19850412").should eq(time)
    end

    it "parses ordinal date" do
      time = Time.new(1985, 4, 12, kind: Time::Kind::Utc)
      Time::Format::ISO_8601_DATE.parse("1985-102").should eq(time)
      Time::Format::ISO_8601_DATE.parse("1985102").should eq(time)
    end

    pending "parses week date" do
      Time::Format::ISO_8601_DATE.parse("1985-W15-5").should eq(time)
      Time::Format::ISO_8601_DATE.parse("1985W155").should eq(time)
    end
  end

  describe "ISO_8601_DATE_TIME" do
    it "formats default format" do
      time = Time.new(1985, 4, 12, 23, 20, 50, kind: Time::Kind::Utc)
      Time::Format::ISO_8601_DATE_TIME.format(time).should eq "1985-04-12T23:20:50Z"
    end
    it "parses calendar date" do
      time = Time.new(1985, 4, 12, 23, 20, 50, kind: Time::Kind::Utc)
      Time::Format::ISO_8601_DATE_TIME.parse("1985-04-12T23:20:50Z").should eq(time)
      Time::Format::ISO_8601_DATE_TIME.parse("19850412T232050Z").should eq(time)
    end
    it "parses ordinal date" do
      time = Time.new(1985, 4, 12, 23, 20, 50, kind: Time::Kind::Utc)
      Time::Format::ISO_8601_DATE_TIME.parse("1985-102T23:20:50Z").should eq(time)
      Time::Format::ISO_8601_DATE_TIME.parse("1985102T232050Z").should eq(time)
    end
    it "parses hour:minutes" do
      time = Time.new(1985, 4, 12, 23, 20, kind: Time::Kind::Utc)
      Time::Format::ISO_8601_DATE_TIME.parse("1985-102T23:20Z").should eq(time)
      Time::Format::ISO_8601_DATE_TIME.parse("1985102T2320Z").should eq(time)
    end
    it "parses hour" do
      time = Time.new(1985, 4, 12, 23, kind: Time::Kind::Utc)
      Time::Format::ISO_8601_DATE_TIME.parse("1985-102T23Z").should eq(time)
      Time::Format::ISO_8601_DATE_TIME.parse("1985102T23Z").should eq(time)
    end

    pending "week date" do
      Time::Format::ISO_8601_DATE_TIME.parse("1985-W15-5TZ").should eq(time)
      Time::Format::ISO_8601_DATE_TIME.parse("1985W155T23:20:50Z").should eq(time)
    end
  end
end
