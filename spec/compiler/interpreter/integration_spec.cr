{% skip_file if flag?(:without_interpreter) %}
require "./spec_helper"

describe Crystal::Repl::Interpreter do
  context "integration" do
    it "does Int32#to_s" do
      interpret(<<-CRYSTAL, prelude: "prelude").should eq(%("123456789"))
        123456789.to_s
      CRYSTAL
    end

    it "does Float64#to_s (simple)" do
      interpret(<<-CRYSTAL, prelude: "prelude").should eq(%("1.5"))
        1.5.to_s
      CRYSTAL
    end

    it "does Float64#to_s (complex)" do
      interpret(<<-CRYSTAL, prelude: "prelude").should eq(%("123456789.12345"))
        123456789.12345.to_s
      CRYSTAL
    end

    it "does Range#to_a, Array#to_s" do
      interpret(<<-CRYSTAL, prelude: "prelude").should eq(%("[1, 2, 3, 4, 5]"))
        (1..5).to_a.to_s
      CRYSTAL
    end

    it "does some Hash methods" do
      interpret(<<-CRYSTAL, prelude: "prelude").should eq("90")
        h = {} of Int32 => Int32
        10.times do |i|
          h[i] = i * 2
        end
        h.values.sum
      CRYSTAL
    end

    it "does CSV" do
      interpret(<<-CRYSTAL, prelude: "prelude").should eq((1..6).sum.to_s)
        require "csv"

        csv = CSV.new <<-CSV, headers: true
          a, b, c
          1, 2, 3
          4, 5, 6
        CSV

        sum = 0
        csv.each do
          {"a", "b", "c"}.each do |name|
            sum += csv[name].to_i
          end
        end
        sum
      CRYSTAL
    end

    it "does JSON" do
      interpret(<<-CRYSTAL, prelude: "prelude").should eq("6")
        require "json"

        json = JSON.parse <<-JSON
          {"a": [1, 2, 3]}
          JSON
        json.as_h["a"].as_a.sum(&.as_i)
      CRYSTAL
    end

    it "does JSON::Serializable" do
      interpret(<<-CRYSTAL, prelude: "prelude").should eq("3")
        require "json"

        record Point, x : Int32, y : Int32 do
          include JSON::Serializable
        end

        point = Point.from_json <<-JSON
          {"x": 1, "y": 2}
        JSON
        point.x + point.y
      CRYSTAL
    end

    it "does YAML" do
      interpret(<<-CRYSTAL, prelude: "prelude").should eq("6")
        require "yaml"

        yaml = YAML.parse <<-YAML
          a:
            - 1
            - 2
            - 3
          YAML
        yaml.as_h["a"].as_a.sum(&.as_i)
      CRYSTAL
    end

    it "does YAML::Serializable" do
      interpret(<<-CRYSTAL, prelude: "prelude").should eq("3")
        require "yaml"

        record Point, x : Int32, y : Int32 do
          include YAML::Serializable
        end

        point = Point.from_yaml <<-YAML
          x: 1
          y: 2
        YAML
        point.x + point.y
      CRYSTAL
    end

    pending "does XML" do
      interpret(<<-CRYSTAL, prelude: "prelude").should eq("3")
        require "xml"

        doc = XML.parse(<<-XML
          <?xml version='1.0' encoding='UTF-8'?>
          <people>
            <person id="1" id2="2">
              <name>John</name>
            </person>
          </people>
          XML
        )
        attrs = doc.root.not_nil!.children[1].attributes
        id = attrs["id"].content.to_i
        id2 = attrs["id2"].content.to_i
        id + id2
        CRYSTAL
    end

    it "does String#includes?" do
      interpret(<<-CRYSTAL, prelude: "prelude").should eq("true")
        a = "Negative array size: -1"
        b = "Negative array size"
        a.includes?(b)
      CRYSTAL
    end

    it "does IO.pipe (checks that StaticArray is passed correctly to C calls)" do
      interpret(<<-CRYSTAL, prelude: "prelude").should eq(%("hello"))
        IO.pipe do |r, w|
          w.puts "hello"
          r.gets.not_nil!
        end
      CRYSTAL
    end

    it "does caller" do
      interpret(<<-CRYSTAL, prelude: "prelude").should eq(%(":6:5 in 'bar'"))
        def foo
          bar
        end

        def bar
          caller[0]
        end

        foo
      CRYSTAL
    end
  end
end
