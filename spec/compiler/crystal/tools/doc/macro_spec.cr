require "../../../spec_helper"

private def assert_args_to_s(item, to_s_output, to_html_output = to_s_output, *, file = __FILE__, line = __LINE__)
  item.args_to_s.should eq(to_s_output), file: file, line: line
  item.args_to_html.should eq(to_html_output), file: file, line: line
end

describe Doc::Macro do
  describe "args_to_s" do
    it "shows simple args" do
      program = Program.new
      generator = Doc::Generator.new program, ["."]
      doc_type = Doc::Type.new generator, program

      a_macro = Macro.new "foo", ["foo".arg, "bar".arg]
      doc_macro = Doc::Macro.new generator, doc_type, a_macro
      assert_args_to_s(doc_macro, "(foo, bar)")
    end

    it "shows splat arg" do
      program = Program.new
      generator = Doc::Generator.new program, ["."]
      doc_type = Doc::Type.new generator, program

      a_macro = Macro.new "foo", ["foo".arg], splat_index: 0
      doc_macro = Doc::Macro.new generator, doc_type, a_macro
      assert_args_to_s(doc_macro, "(*foo)")
    end

    it "shows simple arg and splat arg" do
      program = Program.new
      generator = Doc::Generator.new program, ["."]
      doc_type = Doc::Type.new generator, program

      a_macro = Macro.new "foo", ["foo".arg, "bar".arg], splat_index: 1
      doc_macro = Doc::Macro.new generator, doc_type, a_macro
      assert_args_to_s(doc_macro, "(foo, *bar)")
    end

    it "shows double splat arg" do
      program = Program.new
      generator = Doc::Generator.new program, ["."]
      doc_type = Doc::Type.new generator, program

      a_macro = Macro.new "foo", double_splat: "foo".arg
      doc_macro = Doc::Macro.new generator, doc_type, a_macro
      assert_args_to_s(doc_macro, "(**foo)")
    end

    it "shows double splat arg" do
      program = Program.new
      generator = Doc::Generator.new program, ["."]
      doc_type = Doc::Type.new generator, program

      a_macro = Macro.new "foo", double_splat: "foo".arg
      doc_macro = Doc::Macro.new generator, doc_type, a_macro
      assert_args_to_s(doc_macro, "(**foo)")
    end

    it "shows simple arg and double splat arg" do
      program = Program.new
      generator = Doc::Generator.new program, ["."]
      doc_type = Doc::Type.new generator, program

      a_macro = Macro.new "foo", ["foo".arg], double_splat: "bar".arg
      doc_macro = Doc::Macro.new generator, doc_type, a_macro
      assert_args_to_s(doc_macro, "(foo, **bar)")
    end

    it "shows block arg" do
      program = Program.new
      generator = Doc::Generator.new program, ["."]
      doc_type = Doc::Type.new generator, program

      a_macro = Macro.new "foo", block_arg: "foo".arg
      doc_macro = Doc::Macro.new generator, doc_type, a_macro
      assert_args_to_s(doc_macro, "(&foo)")
    end

    it "shows simple arg and block arg" do
      program = Program.new
      generator = Doc::Generator.new program, ["."]
      doc_type = Doc::Type.new generator, program

      a_macro = Macro.new "foo", ["foo".arg], block_arg: "bar".arg
      doc_macro = Doc::Macro.new generator, doc_type, a_macro
      assert_args_to_s(doc_macro, "(foo, &bar)")
    end

    it "shows external name of arg" do
      program = Program.new
      generator = Doc::Generator.new program, ["."]
      doc_type = Doc::Type.new generator, program

      a_macro = Macro.new "foo", ["foo".arg(external_name: "bar")]
      doc_macro = Doc::Macro.new generator, doc_type, a_macro
      assert_args_to_s(doc_macro, "(bar foo)")
    end

    it "shows external name of arg with quotes and escaping" do
      program = Program.new
      generator = Doc::Generator.new program, ["."]
      doc_type = Doc::Type.new generator, program

      a_macro = Macro.new "foo", ["foo".arg(external_name: "<<-< uouo fish life")]
      doc_macro = Doc::Macro.new generator, doc_type, a_macro
      assert_args_to_s(doc_macro,
        %(("<<-< uouo fish life" foo)),
        "(&quot;&lt;&lt;-&lt; uouo fish life&quot; foo)")
    end

    it "shows default value with highlighting" do
      program = Program.new
      generator = Doc::Generator.new program, ["."]
      doc_type = Doc::Type.new generator, program

      a_macro = Macro.new "foo", ["foo".arg(default_value: 1.int32)]
      doc_macro = Doc::Macro.new generator, doc_type, a_macro
      assert_args_to_s(doc_macro, %((foo = 1)), %((foo = <span class="n">1</span>)))
    end
  end
end
