require "./spec_helper"
require "mime"

module MIME
  def self.initialized
    @@initialized
  end

  def self.reset!
    @@initialized = false
    @@types = {} of String => String
    @@types_lower = {} of String => String
    @@extensions = {} of String => Set(String)
  end
end

describe MIME do
  before_each do
    MIME.reset!
  end

  after_each do
    MIME.reset!
  end

  it ".from_extension" do
    MIME.init
    MIME.from_extension(".html").partition(';')[0].should eq "text/html"
    MIME.from_extension(".HTML").partition(';')[0].should eq "text/html"

    expect_raises KeyError do
      MIME.from_extension(".fooobar")
    end
    MIME.from_extension(".fooobar", "default/fooobar").should eq "default/fooobar"
    MIME.from_extension(".fooobar") { "default/fooobar" }.should eq "default/fooobar"
  end

  it ".from_extension?" do
    MIME.init
    MIME.from_extension?(".html").should eq MIME.from_extension(".html")
    MIME.from_extension?(".HTML").should eq MIME.from_extension(".HTML")

    MIME.from_extension?(".fooobar").should be_nil
  end

  describe ".from_filename" do
    it String do
      MIME.init
      MIME.from_filename("test.html").should eq MIME.from_extension(".html")
      MIME.from_filename("foo/bar.not-exists", "foo/bar-exist").should eq "foo/bar-exist"
      MIME.from_filename("foo/bar.not-exists") { "foo/bar-exist" }.should eq "foo/bar-exist"
    end

    it Path do
      MIME.init
      MIME.from_filename(Path["test.html"]).should eq MIME.from_extension(".html")
      MIME.from_filename(Path["foo/bar.not-exists"], "foo/bar-exist").should eq "foo/bar-exist"
      MIME.from_filename(Path["foo/bar.not-exists"]) { "foo/bar-exist" }.should eq "foo/bar-exist"
    end
  end

  describe ".from_filename?" do
    it String do
      MIME.init
      MIME.from_filename?("test.html").should eq MIME.from_extension(".html")
    end

    it Path do
      MIME.init
      MIME.from_filename?(Path["test.html"]).should eq MIME.from_extension(".html")
    end
  end

  describe ".register" do
    it "registers new type" do
      MIME.init(load_defaults: false)
      MIME.register(".Custom-Type", "text/custom-type")

      MIME.from_extension(".Custom-Type").should eq "text/custom-type"
      MIME.from_extension(".custom-type").should eq "text/custom-type"
      MIME.extensions("text/custom-type").should eq Set{".Custom-Type"}

      MIME.register(".custom-type2", "text/custom-type")
      MIME.extensions("text/custom-type").should eq Set{".Custom-Type", ".custom-type2"}

      MIME.register(".custom-type", "text/custom-type-lower")
      MIME.from_extension(".custom-type").should eq "text/custom-type-lower"
      MIME.from_extension(".Custom-Type").should eq "text/custom-type"
    end

    it "fails for invalid extension" do
      expect_raises ArgumentError, "Extension does not start with a dot" do
        MIME.register("foo", "text/foo")
      end

      expect_raises ArgumentError, "String contains null byte" do
        MIME.register(".foo\0", "text/foo")
      end
    end
  end

  describe ".extensions" do
    it "lists extensions" do
      MIME.init
      MIME.extensions("text/html").should contain ".htm"
      MIME.extensions("text/html").should contain ".html"
    end

    it "returns empty set" do
      MIME.init(load_defaults: false)
      MIME.extensions("foo/bar").should eq Set(String).new
    end

    it "recognizes overridden types" do
      MIME.init(load_defaults: false)
      MIME.register(".custom-type-overridden", "text/custom-type-overridden")
      MIME.register(".custom-type-overridden", "text/custom-type-override")

      MIME.extensions("text/custom-type-overridden").should eq Set(String).new
    end
  end

  it "parses media types" do
    MIME.init(load_defaults: false)
    MIME.register(".parse-media-type1", "text/html; charset=utf-8")
    MIME.extensions("text/html").should contain(".parse-media-type1")

    MIME.register(".parse-media-type2", "text/html; foo = bar; bar= foo ;")
    MIME.extensions("text/html").should contain(".parse-media-type2")

    MIME.register(".parse-media-type3", "foo/bar")
    MIME.extensions("foo/bar").should contain(".parse-media-type3")

    MIME.register(".parse-media-type4", " form-data ; name=foo")
    MIME.extensions("form-data").should contain(".parse-media-type4")

    MIME.register(".parse-media-type41", %(FORM-DATA;name="foo"))
    MIME.extensions("form-data").should contain(".parse-media-type41")

    MIME.register(".parse-media-type5", %( FORM-DATA ; name="foo"))
    MIME.extensions("form-data").should contain(".parse-media-type5")

    expect_raises ArgumentError, "Invalid media type" do
      MIME.register(".parse-media-type6", ": inline; attachment; filename=foo.html")
    end

    expect_raises ArgumentError, "Invalid media type" do
      MIME.register(".parse-media-type7", "filename=foo.html, filename=bar.html")
    end

    expect_raises ArgumentError, "Invalid media type" do
      MIME.register(".parse-media-type8", %("foo; filename=bar;baz"; filename=qux))
    end

    expect_raises ArgumentError, "Invalid media type" do
      MIME.register(".parse-media-type9", "x=y; filename=foo.html")
    end

    expect_raises ArgumentError, "Invalid media type" do
      MIME.register(".parse-media-type10", "filename=foo.html")
    end
  end

  it ".load_mime_database" do
    MIME.init(load_defaults: false)
    MIME.from_extension?(".bar").should be_nil
    MIME.from_extension?(".fbaz").should be_nil

    MIME.load_mime_database IO::Memory.new <<-EOF
      foo/bar          bar
      foo/baz          baz fbaz #foobaz
      # foo/foo        foo
    EOF

    MIME.from_extension?(".bar").should eq "foo/bar"
    MIME.from_extension?(".fbaz").should eq "foo/baz"
    MIME.from_extension?(".#foobaz").should be_nil
    MIME.from_extension?(".foobaz").should be_nil
    MIME.from_extension?(".foo").should be_nil
  end

  describe ".init" do
    it "loads defaults" do
      MIME.init
      MIME.initialized.should be_true
      MIME.from_extension(".html").partition(';')[0].should eq "text/html"
    end

    it "skips loading defaults" do
      MIME.init(load_defaults: false)
      MIME.initialized.should be_true
      MIME.from_extension?(".html").should be_nil
    end

    it "loads file" do
      MIME.initialized.should be_false
      MIME.init(datapath("mime.types"))
      MIME.from_extension?(".foo").should eq "foo/bar"
    end
  end

  {% if flag?(:win32) %}
    it "loads MIME data from registry" do
      MIME.register(".wma", "non-initialized")
      MIME.init
      MIME.from_extension?(".wma").should eq "audio/x-ms-wma"
    end
  {% end %}
end
