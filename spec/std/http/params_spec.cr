require "spec"
require "http/params"

module HTTP
  describe Params do
    describe ".parse" do
      {
        {"", {} of String => Array(String)},
        {"   ", {"   " => [""]}},
        {"foo=bar", {"foo" => ["bar"]}},
        {"foo=bar&foo=baz", {"foo" => ["bar", "baz"]}},
        {"foo=bar&baz=qux", {"foo" => ["bar"], "baz" => ["qux"]}},
        {"foo=bar;baz=qux", {"foo" => ["bar"], "baz" => ["qux"]}},
        {"foo=hello%2Bworld", {"foo" => ["hello+world"]}},
        {"foo=hello+world", {"foo" => ["hello world"]}},
        {"foo=", {"foo" => [""]}},
        {"foo", {"foo" => [""]}},
        {"foo=&bar", {"foo" => [""], "bar" => [""]}},
        {"bar&foo", {"bar" => [""], "foo" => [""]}},
        {"foo=bar=qux", {"foo" => ["bar=qux"]}},
      }.each do |(from, to)|
        it "parses #{from}" do
          Params.parse(from).should eq(Params.new(to))
        end
      end
    end

    describe ".build" do
      {
        {"foo=bar", {"foo" => ["bar"]}},
        {"foo=bar&foo=baz", {"foo" => ["bar", "baz"]}},
        {"foo=bar&baz=qux", {"foo" => ["bar"], "baz" => ["qux"]}},
        {"foo=hello%2Bworld", {"foo" => ["hello+world"]}},
        {"foo=hello+world", {"foo" => ["hello world"]}},
        {"foo=", {"foo" => [""]}},
        {"foo=&bar=", {"foo" => [""], "bar" => [""]}},
        {"bar=&foo=", {"bar" => [""], "foo" => [""]}},
      }.each do |(to, from)|
        it "builds form from #{from}" do
          encoded = Params.build do |form|
            from.each do |key, values|
              values.each do |value|
                form.add(key, value)
              end
            end
          end

          encoded.should eq(to)
        end
      end
    end

    describe ".encode" do
      it "builds from hash" do
        encoded = Params.encode({"foo" => "bar", "baz" => "quux"})
        encoded.should eq("foo=bar&baz=quux")
      end

      it "builds from named tuple" do
        encoded = Params.encode({foo: "bar", baz: "quux"})
        encoded.should eq("foo=bar&baz=quux")
      end
    end

    describe "#to_s" do
      it "serializes params to http form" do
        params = Params.parse("foo=bar&foo=baz&baz=qux")
        params.to_s.should eq("foo=bar&foo=baz&baz=qux")
      end
    end

    describe "#[](name)" do
      it "returns first value for provided param name" do
        params = Params.parse("foo=bar&foo=baz&baz=qux")
        params["foo"].should eq("bar")
        params["baz"].should eq("qux")
      end

      it "raises KeyError when there is no such param" do
        params = Params.parse("foo=bar&foo=baz&baz=qux")
        expect_raises KeyError do
          params["non_existent_param"]
        end
      end
    end

    describe "#[]?(name)" do
      it "returns first value for provided param name" do
        params = Params.parse("foo=bar&foo=baz&baz=qux")
        params["foo"]?.should eq("bar")
        params["baz"]?.should eq("qux")
      end

      it "return nil when there is no such param" do
        params = Params.parse("foo=bar&foo=baz&baz=qux")
        params["non_existent_param"]?.should eq(nil)
      end
    end

    describe "#has_key?(name)" do
      it "returns true if param with provided name exists" do
        params = Params.parse("foo=bar&foo=baz&baz=qux")
        params.has_key?("foo").should eq(true)
        params.has_key?("baz").should eq(true)
      end

      it "return false if param with provided name does not exist" do
        params = Params.parse("foo=bar&foo=baz&baz=qux")
        params.has_key?("non_existent_param").should eq(false)
      end
    end

    describe "#[]=(name, value)" do
      it "sets first value for provided param name" do
        params = Params.parse("foo=bar&foo=baz&baz=qux")
        params["foo"] = "notfoo"
        params.fetch_all("foo").should eq(["notfoo", "baz"])
      end

      it "adds new name => value pair if there is no such param" do
        params = Params.parse("foo=bar&foo=baz&baz=qux")
        params["non_existent_param"] = "test"
        params.fetch_all("non_existent_param").should eq(["test"])
      end
    end

    describe "#fetch(name)" do
      it "returns first value for provided param name" do
        params = Params.parse("foo=bar&foo=baz&baz=qux")
        params.fetch("foo").should eq("bar")
        params.fetch("baz").should eq("qux")
      end

      it "raises KeyError when there is no such param" do
        params = Params.parse("foo=bar&foo=baz&baz=qux")
        expect_raises KeyError do
          params.fetch("non_existent_param")
        end
      end
    end

    describe "#fetch(name, default)" do
      it "returns first value for provided param name" do
        params = Params.parse("foo=bar&foo=baz&baz=qux")
        params.fetch("foo", "aDefault").should eq("bar")
        params.fetch("baz", "aDefault").should eq("qux")
      end

      it "return default value when there is no such param" do
        params = Params.parse("foo=bar&foo=baz&baz=qux")
        params.fetch("non_existent_param", "aDefault").should eq("aDefault")
      end
    end

    describe "#fetch(name, &block)" do
      it "returns first value for provided param name" do
        params = Params.parse("foo=bar&foo=baz&baz=qux")
        params.fetch("foo") { "fromBlock" }.should eq("bar")
        params.fetch("baz") { "fromBlock" }.should eq("qux")
      end

      it "return default value when there is no such param" do
        params = Params.parse("foo=bar&foo=baz&baz=qux")
        params.fetch("non_existent_param") { "fromBlock" }.should eq("fromBlock")
      end
    end

    describe "#fetch_all(name)" do
      it "fetches list of all values for provided param name" do
        params = Params.parse("foo=bar&foo=baz&baz=qux&iamempty")
        params.fetch_all("foo").should eq(["bar", "baz"])
        params.fetch_all("baz").should eq(["qux"])
        params.fetch_all("iamempty").should eq([""])
        params.fetch_all("non_existent_param").should eq([] of String)
      end
    end

    describe "#add(name, value)" do
      it "appends new value for provided param name" do
        params = Params.parse("foo=bar&foo=baz&baz=qux&iamempty")

        params.add("foo", "zeit")
        params.fetch_all("foo").should eq(["bar", "baz", "zeit"])

        params.add("baz", "exit")
        params.fetch_all("baz").should eq(["qux", "exit"])

        params.add("iamempty", "not_empty_anymore")
        params.fetch_all("iamempty").should eq(["not_empty_anymore"])

        params.add("non_existent_param", "something")
        params.fetch_all("non_existent_param").should eq(["something"])
      end
    end

    describe "#set_all(name, values)" do
      it "sets values for provided param name" do
        params = Params.parse("foo=bar&foo=baz&baz=qux")

        params.set_all("baz", ["hello", "world"])
        params.fetch_all("baz").should eq(["hello", "world"])

        params.set_all("foo", ["something"])
        params.fetch_all("foo").should eq(["something"])

        params.set_all("non_existent_param", ["something", "else"])
        params.fetch_all("non_existent_param").should eq(["something", "else"])
      end
    end

    describe "#each" do
      it "calls provided proc for each name, value pair, including multiple values per one param name" do
        received = [] of {String, String}

        params = Params.parse("foo=bar&foo=baz&baz=qux")
        params.each do |name, value|
          received << {name, value}
        end

        received.should eq([
          {"foo", "bar"},
          {"foo", "baz"},
          {"baz", "qux"},
        ])
      end
    end

    describe "#delete" do
      it "deletes first value for provided param name and returns it" do
        params = Params.parse("foo=bar&foo=baz&baz=qux")

        params.delete("foo").should eq("bar")
        params.fetch_all("foo").should eq(["baz"])

        params.delete("baz").should eq("qux")
        expect_raises KeyError do
          params.fetch("baz")
        end
      end
    end

    describe "#delete_all" do
      it "deletes all values for provided param name and returns them" do
        params = Params.parse("foo=bar&foo=baz&baz=qux")

        params.delete_all("foo").should eq(["bar", "baz"])
        expect_raises KeyError do
          params.fetch("foo")
        end
      end
    end
  end
end
