require "spec"

describe "Time::Format" do
  describe "RFC_3339" do
    it "parses regular format" do
      time = Time.utc(2016, 2, 15)
      Time::Format::RFC_3339.format(time).should eq "2016-02-15T00:00:00Z"
      Time::Format::RFC_3339.format(Time.local(2016, 2, 15, location: Time::Location.fixed(3600))).should eq "2016-02-15T00:00:00+01:00"
      Time::Format::RFC_3339.parse("2016-02-15T00:00:00+00:00").should eq time
      Time::Format::RFC_3339.parse("2016-02-15t00:00:00+00:00").should eq time
      Time::Format::RFC_3339.parse("2016-02-15 00:00:00+00:00").should eq time
      Time::Format::RFC_3339.parse("2016-02-15T00:00:00Z").should eq time
      Time::Format::RFC_3339.parse("2016-02-15T00:00:00.0000000+00:00").should eq time
    end
  end

  describe "RFC_2822" do
    it "parses regular format" do
      time = Time.utc(2016, 2, 15)
      Time::Format::RFC_2822.format(time).should eq "Mon, 15 Feb 2016 00:00:00 +0000"
      Time::Format::RFC_2822.parse("Mon, 15 Feb 2016 00:00:00 +0000").should eq time
      Time::Format::RFC_2822.parse("Mon, 15 Feb 16 00:00 UT").should eq time
      Time::Format::RFC_2822.parse(" Mon , 14 Feb 2016 20 : 00 : 00 EDT (comment)").to_utc.should eq time
    end
  end

  describe "ISO_8601_DATE" do
    it "formats default format" do
      time = Time.utc(1985, 4, 12)
      Time::Format::ISO_8601_DATE.format(time).should eq "1985-04-12"
    end

    it "parses calendar date" do
      time = Time.utc(1985, 4, 12)
      Time::Format::ISO_8601_DATE.parse("1985-04-12").should eq(time)
      Time::Format::ISO_8601_DATE.parse("19850412").should eq(time)
    end

    it "parses ordinal date" do
      time = Time.utc(1985, 4, 12)
      Time::Format::ISO_8601_DATE.parse("1985-102").should eq(time)
      Time::Format::ISO_8601_DATE.parse("1985102").should eq(time)
    end

    it "parses week date" do
      time = Time.utc(1985, 4, 12)
      Time::Format::ISO_8601_DATE.parse("1985-W15-5").should eq(time)
      Time::Format::ISO_8601_DATE.parse("1985W155").should eq(time)

      Time::Format::ISO_8601_DATE.parse("2004-W53-6").should eq(Time.utc(2005, 1, 1))
      Time::Format::ISO_8601_DATE.parse("2004-W53-7").should eq(Time.utc(2005, 1, 2))
      Time::Format::ISO_8601_DATE.parse("2005-W52-6").should eq(Time.utc(2005, 12, 31))
      Time::Format::ISO_8601_DATE.parse("2005-W52-7").should eq(Time.utc(2006, 1, 1))
      Time::Format::ISO_8601_DATE.parse("2006-W01-1").should eq(Time.utc(2006, 1, 2))
      Time::Format::ISO_8601_DATE.parse("2006-W52-7").should eq(Time.utc(2006, 12, 31))
      Time::Format::ISO_8601_DATE.parse("2007-W01-1").should eq(Time.utc(2007, 1, 1))
      Time::Format::ISO_8601_DATE.parse("2007-W52-7").should eq(Time.utc(2007, 12, 30))
      Time::Format::ISO_8601_DATE.parse("2008-W01-1").should eq(Time.utc(2007, 12, 31))
      Time::Format::ISO_8601_DATE.parse("2008-W01-2").should eq(Time.utc(2008, 1, 1))
      Time::Format::ISO_8601_DATE.parse("2008-W52-7").should eq(Time.utc(2008, 12, 28))
      Time::Format::ISO_8601_DATE.parse("2009-W01-1").should eq(Time.utc(2008, 12, 29))
      Time::Format::ISO_8601_DATE.parse("2009-W01-2").should eq(Time.utc(2008, 12, 30))
      Time::Format::ISO_8601_DATE.parse("2009-W01-3").should eq(Time.utc(2008, 12, 31))
      Time::Format::ISO_8601_DATE.parse("2009-W01-4").should eq(Time.utc(2009, 1, 1))
      Time::Format::ISO_8601_DATE.parse("2009-W53-4").should eq(Time.utc(2009, 12, 31))
      Time::Format::ISO_8601_DATE.parse("2009-W53-5").should eq(Time.utc(2010, 1, 1))
      Time::Format::ISO_8601_DATE.parse("2009-W53-6").should eq(Time.utc(2010, 1, 2))
      Time::Format::ISO_8601_DATE.parse("2009-W53-7").should eq(Time.utc(2010, 1, 3))
    end
  end

  describe "ISO_8601_DATE_TIME" do
    it "formats default format" do
      time = Time.utc(1985, 4, 12, 23, 20, 50)
      Time::Format::ISO_8601_DATE_TIME.format(time).should eq "1985-04-12T23:20:50Z"
    end

    it "parses calendar date" do
      time = Time.utc(1985, 4, 12, 23, 20, 50)
      Time::Format::ISO_8601_DATE_TIME.parse("1985-04-12T23:20:50Z").should eq(time)
      Time::Format::ISO_8601_DATE_TIME.parse("19850412T232050Z").should eq(time)
    end

    it "parses ordinal date" do
      time = Time.utc(1985, 4, 12, 23, 20, 50)
      Time::Format::ISO_8601_DATE_TIME.parse("1985-102T23:20:50Z").should eq(time)
      Time::Format::ISO_8601_DATE_TIME.parse("1985102T232050Z").should eq(time)
    end

    it "parses hour:minutes" do
      time = Time.utc(1985, 4, 12, 23, 20)
      Time::Format::ISO_8601_DATE_TIME.parse("1985-102T23:20Z").should eq(time)
      Time::Format::ISO_8601_DATE_TIME.parse("1985102T2320Z").should eq(time)
    end

    it "parses decimal fractions" do
      time = Time.utc(1985, 4, 12, 23, 30)
      Time::Format::ISO_8601_DATE_TIME.parse("1985-4-12T23.5Z").should eq(time)
      Time::Format::ISO_8601_DATE_TIME.parse("1985-4-12T23.5Z").should eq(time)
      Time::Format::ISO_8601_DATE_TIME.parse("1985-4-12T23.50000000000Z").should eq(time)
      Time::Format::ISO_8601_DATE_TIME.parse("1985-4-12T23.50000000000Z").should eq(time)
    end

    it "parses hour" do
      time = Time.utc(1985, 4, 12, 23)
      Time::Format::ISO_8601_DATE_TIME.parse("1985-102T23Z").should eq(time)
      Time::Format::ISO_8601_DATE_TIME.parse("1985102T23Z").should eq(time)
    end

    it "week date" do
      time = Time.utc(1985, 4, 12, 23, 20, 50)
      Time::Format::ISO_8601_DATE_TIME.parse("1985-W15-5T23:20:50Z").should eq(time)
      Time::Format::ISO_8601_DATE_TIME.parse("1985W155T23:20:50Z").should eq(time)
    end
  end
end
