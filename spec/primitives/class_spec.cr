require "spec"
require "../support/interpreted"

describe Class do
  pending_interpreted describe: "#crystal_instance_type_name" do
    it "returns the name of class type" do
      String.crystal_instance_type_name.should eq "String"
      Int32.crystal_instance_type_name.should eq "Int32"
      Int.crystal_instance_type_name.should eq "Int"
      Reference.crystal_instance_type_name.should eq "Reference"
      Struct.crystal_instance_type_name.should eq "Struct"
      Value.crystal_instance_type_name.should eq "Value"
    end

    it "returns the name of Class" do
      Class.crystal_instance_type_name.should eq "Class"
      Int32.class.crystal_instance_type_name.should eq "Class"
    end

    it "returns the name of generic class type" do
      Hash.crystal_instance_type_name.should eq "Hash(K, V)"
      Hash(Int32, String).crystal_instance_type_name.should eq "Hash(Int32, String)"
    end

    it "returns the name of module type" do
      Enumerable.crystal_instance_type_name.should eq "Enumerable(T)"
      Enumerable(Int32).crystal_instance_type_name.should eq "Enumerable(Int32)"
    end

    it "returns the name of union type" do
      (Int32 | String).crystal_instance_type_name.should eq "(Int32 | String)"
      Union(Int32, String).crystal_instance_type_name.should eq "(Int32 | String)"
    end

    it "returns the name of virtual type" do
      ArgumentError.as(Exception.class).crystal_instance_type_name.should eq "ArgumentError"
      IndexError.as(Exception.class).crystal_instance_type_name.should eq "IndexError"
      Exception.as(Exception.class).crystal_instance_type_name.should eq "Exception"

      (ArgumentError | IndexError).crystal_instance_type_name.should eq "Exception"
    end

    it "returns the name of enum type" do
      Errno.crystal_instance_type_name.should eq "Errno"
      Regex::MatchOptions.crystal_instance_type_name.should eq "Regex::MatchOptions"
    end
  end
end
