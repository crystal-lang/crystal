require "spec"
require "uri/params"

class URI
  describe Params do
    describe ".new" do
      it { Params.new.should eq(Params.parse("")) }
    end

    describe ".parse" do
      {
        {"", {} of String => Array(String)},
        {"&&", {} of String => Array(String)},
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

      it "turns spaces to %20 if wanted" do
        encoded = Params.build(space_to_plus: false) do |form|
          form.add("foo bar", "hello world")
        end

        encoded.should eq("foo%20bar=hello%20world")
      end

      it "builds with IO" do
        io = IO::Memory.new
        Params.build(io) do |form|
          form.add("custom", "key")
        end
        io.to_s.should eq("custom=key")
      end
    end

    describe ".encode" do
      it "builds from hash" do
        encoded = Params.encode({"foo" => "bar", "baz" => ["quux", "quuz"]})
        encoded.should eq("foo=bar&baz=quux&baz=quuz")
      end

      it "builds from hash with IO" do
        io = IO::Memory.new
        Params.encode(io, {"foo" => "bar", "baz" => ["quux", "quuz"]})
        io.to_s.should eq("foo=bar&baz=quux&baz=quuz")
      end

      it "builds from named tuple" do
        encoded = Params.encode({foo: "bar", baz: ["quux", "quuz"]})
        encoded.should eq("foo=bar&baz=quux&baz=quuz")
      end

      it "builds from named tuple with IO" do
        io = IO::Memory.new
        encoded = Params.encode(io, {foo: "bar", baz: ["quux", "quuz"]})
        io.to_s.should eq("foo=bar&baz=quux&baz=quuz")
      end
    end

    describe "#to_s" do
      it "serializes params to http form" do
        params = Params.parse("foo=bar&foo=baz&baz=qux")
        params.to_s.should eq("foo=bar&foo=baz&baz=qux")
      end

      it "turns spaces to + by default" do
        params = Params.parse("foo+bar=hello+world")
        params.to_s.should eq("foo+bar=hello+world")
      end

      it "turns spaces to %20 if space_to_plus is false" do
        params = Params.parse("foo+bar=hello+world")
        params.to_s(space_to_plus: false).should eq("foo%20bar=hello%20world")
      end
    end

    it "#inspect" do
      URI::Params.new.inspect.should eq "URI::Params{}"

      URI::Params{"foo" => ["bar", "baz"], "baz" => ["qux"]}.inspect.should eq %(URI::Params{"foo" => ["bar", "baz"], "baz" => ["qux"]})
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
      it "sets value for provided param name" do
        params = Params.parse("foo=bar&foo=baz&baz=qux")
        params["foo"] = "notfoo"
        params.fetch_all("foo").should eq(["notfoo"])
      end

      it "adds new name => value pair if there is no such param" do
        params = Params.parse("foo=bar&foo=baz&baz=qux")
        params["non_existent_param"] = "test"
        params.fetch_all("non_existent_param").should eq(["test"])
      end

      it "sets value for provided param name (array)" do
        params = Params.parse("foo=bar&foo=baz&baz=qux")
        params["non_existent_param"] = ["test", "something"]
        params.fetch_all("non_existent_param").should eq(["test", "something"])
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

    describe "#dup" do
      it "gives a whole new set of params" do
        ary = ["bar"]
        params = Params{"foo" => ary}
        duped = params.dup

        ary << "baz"

        duped.fetch_all("foo").should eq ["bar"]
        params.fetch_all("foo").should eq ["bar", "baz"]
      end
    end

    describe "#clone" do
      it "gives a whole new set of params" do
        ary = ["bar"]
        params = Params{"foo" => ary}
        duped = params.clone

        ary << "baz"

        duped.fetch_all("foo").should eq ["bar"]
        params.fetch_all("foo").should eq ["bar", "baz"]
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
          params["baz"]
        end
      end
    end

    describe "#delete_all" do
      it "deletes all values for provided param name and returns them" do
        params = Params.parse("foo=bar&foo=baz&baz=qux")

        params.delete_all("foo").should eq(["bar", "baz"])
        expect_raises KeyError do
          params["foo"]
        end
      end
    end

    describe "#merge!" do
      it "modifies the reciever" do
        params = Params.parse("foo=bar&foo=baz&qux=zoo")
        other_params = Params.parse("foo=buzz&foo=extra")

        params.merge!(other_params, replace: false)

        params.to_s.should eq("foo=bar&foo=baz&foo=buzz&foo=extra&qux=zoo")
      end

      describe "does not modify the other params" do
        it "with replace: true" do
          params = Params.parse("foo=bar")
          other_params = Params.parse("foo=buzz&foo=extra")

          params.merge!(other_params, replace: true)
          params.add("foo", "another")

          other_params.to_s.should eq("foo=buzz&foo=extra")
        end

        it "with replace: false" do
          params = Params.parse("foo=bar")
          other_params = Params.parse("foo=buzz&foo=extra")

          params.merge!(other_params, replace: false)
          params.add("foo", "another")

          other_params.to_s.should eq("foo=buzz&foo=extra")
        end
      end
    end

    describe "#merge" do
      it "replaces all values with the same key by default" do
        params = Params.parse("foo=bar&foo=baz&qux=zoo")
        other_params = Params.parse("foo=buzz&foo=extra")

        params.merge(other_params).to_s.should eq("foo=buzz&foo=extra&qux=zoo")
      end

      it "appends values with the same key with replace: false" do
        params = Params.parse("foo=bar&foo=baz&qux=zoo")
        other_params = Params.parse("foo=buzz&foo=extra")

        params.merge(other_params, replace: false).to_s.should eq("foo=bar&foo=baz&foo=buzz&foo=extra&qux=zoo")
      end

      it "does not modify the reciever" do
        params = Params.parse("foo=bar&foo=baz&qux=zoo")
        other_params = Params.parse("foo=buzz&foo=extra")

        params.merge(other_params)

        params.to_s.should eq("foo=bar&foo=baz&qux=zoo")
      end
    end

    describe "#empty?" do
      it "test empty?" do
        Params.parse("foo=bar&foo=baz&baz=qux").empty?.should be_false
        Params.parse("").empty?.should be_true
        Params.new.empty?.should be_true
      end
    end

    describe "#==" do
      it "compares other" do
        a = Params.parse("a=foo&b=bar")
        b = Params.parse("a=bar&b=foo")
        (a == a).should be_true
        (b == b).should be_true
        (a == b).should be_false
      end

      it "compares other types" do
        a = Params.parse("a=foo&b=bar")
        b = "other type"
        (a == b).should be_false
      end
    end
  end
end
