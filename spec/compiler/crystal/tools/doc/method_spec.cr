require "../../../spec_helper"

describe Doc::Method do
  describe "args_to_s" do
    it "shows simple args" do
      program = Program.new
      generator = Doc::Generator.new program, ["."], ".", nil
      doc_type = Doc::Type.new generator, program

      a_def = Def.new "foo", ["foo".arg, "bar".arg]
      doc_method = Doc::Method.new generator, doc_type, a_def, false
      doc_method.args_to_s.should eq("(foo, bar)")
    end

    it "shows splat args" do
      program = Program.new
      generator = Doc::Generator.new program, ["."], ".", nil
      doc_type = Doc::Type.new generator, program

      a_def = Def.new "foo", ["foo".arg], splat_index: 0
      doc_method = Doc::Method.new generator, doc_type, a_def, false
      doc_method.args_to_s.should eq("(*foo)")
    end

    it "shows double splat args" do
      program = Program.new
      generator = Doc::Generator.new program, ["."], ".", nil
      doc_type = Doc::Type.new generator, program

      a_def = Def.new "foo", double_splat: "foo".arg
      doc_method = Doc::Method.new generator, doc_type, a_def, false
      doc_method.args_to_s.should eq("(**foo)")
    end

    it "shows block args" do
      program = Program.new
      generator = Doc::Generator.new program, ["."], ".", nil
      doc_type = Doc::Type.new generator, program

      a_def = Def.new "foo", block_arg: "foo".arg
      doc_method = Doc::Method.new generator, doc_type, a_def, false
      doc_method.args_to_s.should eq("(&foo)")
    end

    it "shows block args if a def has `yield`" do
      program = Program.new
      generator = Doc::Generator.new program, ["."], ".", nil
      doc_type = Doc::Type.new generator, program

      a_def = Def.new "foo", yields: 1
      doc_method = Doc::Method.new generator, doc_type, a_def, false
      doc_method.args_to_s.should eq("(&block)")
    end

    it "shows return type restriction" do
      program = Program.new
      generator = Doc::Generator.new program, ["."], ".", nil
      doc_type = Doc::Type.new generator, program

      a_def = Def.new "foo", return_type: "Foo".path
      doc_method = Doc::Method.new generator, doc_type, a_def, false
      doc_method.args_to_s.should eq(" : Foo")
    end

    it "shows args and return type restriction" do
      program = Program.new
      generator = Doc::Generator.new program, ["."], ".", nil
      doc_type = Doc::Type.new generator, program

      a_def = Def.new "foo", ["foo".arg], return_type: "Foo".path
      doc_method = Doc::Method.new generator, doc_type, a_def, false
      doc_method.args_to_s.should eq("(foo) : Foo")
    end
  end
end
