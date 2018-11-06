require "../../../spec_helper"

describe Doc::Macro do
  describe "args_to_s" do
    it "shows simple args" do
      program = Program.new
      generator = Doc::Generator.new program, ["."], ".", nil
      doc_type = Doc::Type.new generator, program

      a_macro = Macro.new "foo", [Arg.new("foo"), Arg.new("bar")]
      doc_macro = Doc::Macro.new generator, doc_type, a_macro
      doc_macro.args_to_s.should eq("(foo, bar)")
    end

    it "shows splat arg" do
      program = Program.new
      generator = Doc::Generator.new program, ["."], ".", nil
      doc_type = Doc::Type.new generator, program

      a_macro = Macro.new "foo", [Arg.new("foo")], splat_index: 0
      doc_macro = Doc::Macro.new generator, doc_type, a_macro
      doc_macro.args_to_s.should eq("(*foo)")
    end

    it "shows simple arg and splat arg" do
      program = Program.new
      generator = Doc::Generator.new program, ["."], ".", nil
      doc_type = Doc::Type.new generator, program

      a_macro = Macro.new "foo", [Arg.new("foo"), Arg.new("bar")], splat_index: 1
      doc_macro = Doc::Macro.new generator, doc_type, a_macro
      doc_macro.args_to_s.should eq("(foo, *bar)")
    end

    it "shows double splat arg" do
      program = Program.new
      generator = Doc::Generator.new program, ["."], ".", nil
      doc_type = Doc::Type.new generator, program

      a_macro = Macro.new "foo", double_splat: Arg.new("foo")
      doc_macro = Doc::Macro.new generator, doc_type, a_macro
      doc_macro.args_to_s.should eq("(**foo)")
    end

    it "shows double splat arg" do
      program = Program.new
      generator = Doc::Generator.new program, ["."], ".", nil
      doc_type = Doc::Type.new generator, program

      a_macro = Macro.new "foo", double_splat: Arg.new("foo")
      doc_macro = Doc::Macro.new generator, doc_type, a_macro
      doc_macro.args_to_s.should eq("(**foo)")
    end

    it "show simple arg and double splat arg" do
      program = Program.new
      generator = Doc::Generator.new program, ["."], ".", nil
      doc_type = Doc::Type.new generator, program

      a_macro = Macro.new "foo", [Arg.new("foo")], double_splat: Arg.new("bar")
      doc_macro = Doc::Macro.new generator, doc_type, a_macro
      doc_macro.args_to_s.should eq("(foo, **bar)")
    end

    it "show block arg" do
      program = Program.new
      generator = Doc::Generator.new program, ["."], ".", nil
      doc_type = Doc::Type.new generator, program

      a_macro = Macro.new "foo", block_arg: Arg.new("foo")
      doc_macro = Doc::Macro.new generator, doc_type, a_macro
      doc_macro.args_to_s.should eq("(&foo)")
    end

    it "show simple arg and block arg" do
      program = Program.new
      generator = Doc::Generator.new program, ["."], ".", nil
      doc_type = Doc::Type.new generator, program

      a_macro = Macro.new "foo", [Arg.new("foo")], block_arg: Arg.new("bar")
      doc_macro = Doc::Macro.new generator, doc_type, a_macro
      doc_macro.args_to_s.should eq("(foo, &bar)")
    end
  end
end
