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

describe URI::Params::Serializable do
  it "simple type" do
    SimpleType.from_form_data(URI::Params.parse("page=10&strict=true&per_page=5")).should eq SimpleType.new(10, true, 5)
  end

  it "missing required property" do
    expect_raises URI::SerializableError, "Missing required property: 'page'." do
      SimpleType.from_form_data(URI::Params.parse("strict=true&per_page=5"))
    end
  end

  it "with default values" do
    SimpleTypeDefaults.from_form_data(URI::Params.parse("page=10&strict=off")).should eq SimpleTypeDefaults.new(10, false, 10)
  end

  it "with nilable values" do
    SimpleTypeNilable.from_form_data(URI::Params.parse("page=10&strict=true")).should eq SimpleTypeNilable.new(10, true, nil)
  end

  it "with nilable default" do
    SimpleTypeNilableDefault.from_form_data(URI::Params.parse("page=10&strict=true")).should eq SimpleTypeNilableDefault.new(10, true, 20)
  end

  describe "nested type" do
    it "happy path" do
      Search.from_form_data(URI::Params.parse("offset=10&filter[status]=active&filter[total]=3.14"))
        .should eq Search.new Filter.new("active", 3.14), offset: 10
    end

    it "missing nilable nested data" do
      Search.from_form_data(URI::Params.parse("offset=10"))
        .should eq Search.new Filter.new(nil, nil), offset: 10
    end

    it "missing required nested property" do
      expect_raises URI::SerializableError, "Missing required property: 'child[grand_child][name]'." do
        Parent.from_form_data(URI::Params.parse("child[status]=active"))
      end
    end

    it "doubly nested" do
      Parent.from_form_data(URI::Params.parse("child[status]=active&child[grand_child][name]=Fred"))
        .should eq Parent.new Child.new("active", GrandChild.new("Fred"))
    end
  end
end
