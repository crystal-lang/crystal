require "spec"
require "uri/params/serializable"

private record SimpleType, page : Int32, strict : Bool, per_page : UInt8 do
  include URI::Params::Serializable
end

private record SimpleTypeDefaults, page : Int32, strict : Bool, per_page : Int32 = 10 do
  include URI::Params::Serializable
end

private record SimpleTypeNilable, page : Int32, strict : Bool, per_page : Int32? = nil do
  include URI::Params::Serializable
end

private record SimpleTypeNilableDefault, page : Int32, strict : Bool, per_page : Int32? = 20 do
  include URI::Params::Serializable
end

record Filter, status : String?, total : Float64? do
  include URI::Params::Serializable
end

record Search, filter : Filter?, limit : Int32 = 25, offset : Int32 = 0 do
  include URI::Params::Serializable
end

record GrandChild, name : String do
  include URI::Params::Serializable
end

record Child, status : String?, grand_child : GrandChild do
  include URI::Params::Serializable
end

record Parent, child : Child do
  include URI::Params::Serializable
end

module MyConverter
  def self.from_www_form(params : URI::Params, name : String)
    params[name].to_i * 10
  end
end

private record ConverterType, value : Int32 do
  include URI::Params::Serializable

  @[URI::Params::Field(converter: MyConverter)]
  @value : Int32
end

private record GenericConverterType(T), value : Int32 do
  include URI::Params::Serializable

  @[URI::Params::Field(converter: T)]
  @value : Int32
end

class ParentType
  include URI::Params::Serializable

  getter name : String
end

class ChildType < ParentType
end

private struct IgnoreField
  include URI::Params::Serializable

  property name : String
  property age : Int32?

  @[URI::Params::Field(ignore: true)]
  property computed : String?

  def initialize(@name : String, @age : Int32? = nil, @computed : String? = nil)
  end
end

private struct IgnoreSerializeField
  include URI::Params::Serializable

  property name : String

  @[URI::Params::Field(ignore_serialize: true)]
  property secret : String?

  def initialize(@name : String, @secret : String? = nil)
  end
end

private struct IgnoreDeserializeField
  include URI::Params::Serializable

  property name : String

  @[URI::Params::Field(ignore_deserialize: true)]
  property derived : String?

  def initialize(@name : String, @derived : String? = nil)
  end
end

private struct IgnoreSerializeConditional
  include URI::Params::Serializable

  property name : String
  property internal : Bool

  @[URI::Params::Field(ignore_serialize: internal)]
  property extra : String?

  def initialize(@name : String, @internal : Bool, @extra : String? = nil)
  end
end

private record SimpleTypeInitializeOpts, value : Int32 do
  include URI::Params::Serializable

  def initialize(**opts)
    @value = opts.size
  end
end

describe URI::Params::Serializable do
  describe ".from_www_form" do
    it "simple type" do
      SimpleType.from_www_form("page=10&strict=true&per_page=5").should eq SimpleType.new(10, true, 5)
    end

    it "missing required property" do
      expect_raises URI::SerializableError, "Missing required property: 'page'." do
        SimpleType.from_www_form("strict=true&per_page=5")
      end
    end

    it "with default values" do
      SimpleTypeDefaults.from_www_form("page=10&strict=off").should eq SimpleTypeDefaults.new(10, false, 10)
    end

    it "with nilable values" do
      SimpleTypeNilable.from_www_form("page=10&strict=true").should eq SimpleTypeNilable.new(10, true, nil)
    end

    it "with nilable default" do
      SimpleTypeNilableDefault.from_www_form("page=10&strict=true").should eq SimpleTypeNilableDefault.new(10, true, 20)
    end

    it "with custom converter" do
      ConverterType.from_www_form("value=10").should eq ConverterType.new(100)
    end

    it "child type" do
      ChildType.from_www_form("name=Fred").name.should eq "Fred"
    end

    describe "nested type" do
      it "happy path" do
        Search.from_www_form("offset=10&filter[status]=active&filter[total]=3.14")
          .should eq Search.new Filter.new("active", 3.14), offset: 10
      end

      it "missing nilable nested data" do
        Search.from_www_form("offset=10")
          .should eq Search.new Filter.new(nil, nil), offset: 10
      end

      it "missing required nested property" do
        expect_raises URI::SerializableError, "Missing required property: 'child[grand_child][name]'." do
          Parent.from_www_form("child[status]=active")
        end
      end

      it "doubly nested" do
        Parent.from_www_form("child[status]=active&child[grand_child][name]=Fred")
          .should eq Parent.new Child.new("active", GrandChild.new("Fred"))
      end
    end
  end

  describe "#to_www_form" do
    it "simple type" do
      SimpleType.new(10, true, 5).to_www_form.should eq "page=10&strict=true&per_page=5"
    end

    it "nested type path" do
      Search.new(Filter.new("active", 3.14), offset: 10).to_www_form
        .should eq "filter%5Bstatus%5D=active&filter%5Btotal%5D=3.14&limit=25&offset=10"
    end

    it "doubly nested" do
      Parent.new(Child.new("active", GrandChild.new("Fred"))).to_www_form
        .should eq "child%5Bstatus%5D=active&child%5Bgrand_child%5D%5Bname%5D=Fred"
    end
  end

  it "works when type has constructor with double splat parameter (#16140)" do
    SimpleTypeInitializeOpts.from_www_form("value=123").value.should eq(123)
  end

  it "supports generic type variables in converters" do
    GenericConverterType(MyConverter).from_www_form("value=123").value.should eq(1230)
  end

  describe "URI::Params::Field ignore options" do
    describe "ignore: true" do
      it "skips field in serialization" do
        obj = IgnoreField.new("Alice", 30, "computed value")
        obj.to_www_form.should eq "name=Alice&age=30"
      end

      it "skips field in deserialization" do
        obj = IgnoreField.from_www_form("name=Alice&age=30&computed=should+be+ignored")
        obj.name.should eq "Alice"
        obj.age.should eq 30
        obj.computed.should be_nil
      end

      it "round trips without the ignored field" do
        obj = IgnoreField.new("Alice", 30, "computed")
        round_tripped = IgnoreField.from_www_form(obj.to_www_form)
        round_tripped.name.should eq "Alice"
        round_tripped.age.should eq 30
        round_tripped.computed.should be_nil
      end
    end

    describe "ignore_serialize: true" do
      it "skips field in serialization" do
        obj = IgnoreSerializeField.new("Alice", "topsecret")
        obj.to_www_form.should eq "name=Alice"
      end

      it "still deserializes the field" do
        obj = IgnoreSerializeField.from_www_form("name=Alice&secret=topsecret")
        obj.name.should eq "Alice"
        obj.secret.should eq "topsecret"
      end
    end

    describe "ignore_deserialize: true" do
      it "still serializes the field" do
        obj = IgnoreDeserializeField.new("Alice", "derived_value")
        obj.to_www_form.should eq "name=Alice&derived=derived_value"
      end

      it "skips field in deserialization" do
        obj = IgnoreDeserializeField.from_www_form("name=Alice&derived=should+be+ignored")
        obj.name.should eq "Alice"
        obj.derived.should be_nil
      end
    end

    describe "ignore_serialize with runtime expression" do
      it "skips field when expression is truthy" do
        obj = IgnoreSerializeConditional.new("Alice", internal: true, extra: "hidden")
        obj.to_www_form.should eq "name=Alice&internal=true"
      end

      it "includes field when expression is falsy" do
        obj = IgnoreSerializeConditional.new("Alice", internal: false, extra: "visible")
        obj.to_www_form.should eq "name=Alice&internal=false&extra=visible"
      end
    end
  end
end
