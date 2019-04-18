require "../../../spec_helper"

describe Doc::Generator do
  describe "must_include_toplevel?" do
    it "returns false if program has nothing" do
      program = Program.new
      generator = Doc::Generator.new program, ["foo"], ".", "html", nil
      doc_type = Doc::Type.new generator, program

      generator.must_include_toplevel?(doc_type).should be_false
    end

    it "returns true if program has constant" do
      program = Program.new
      generator = Doc::Generator.new program, ["foo"], ".", "html", nil
      doc_type = Doc::Type.new generator, program

      constant = Const.new program, program, "Foo", 1.int32
      constant.add_location Location.new "foo", 1, 1
      program.types[constant.name] = constant

      generator.must_include_toplevel?(doc_type).should be_true
    end

    it "returns false if program has constant which is defined in other place" do
      program = Program.new
      generator = Doc::Generator.new program, ["foo"], ".", "html", nil
      doc_type = Doc::Type.new generator, program

      constant = Const.new program, program, "Foo", 1.int32
      constant.add_location Location.new "bar", 1, 1
      program.types[constant.name] = constant

      generator.must_include_toplevel?(doc_type).should be_false
    end

    it "returns true if program has macro" do
      program = Program.new
      generator = Doc::Generator.new program, ["foo"], ".", "html", nil
      doc_type = Doc::Type.new generator, program

      a_macro = Macro.new "foo"
      a_macro.location = Location.new "foo", 1, 1
      program.add_macro a_macro

      generator.must_include_toplevel?(doc_type).should be_true
    end

    it "returns false if program has macro which is defined in other place" do
      program = Program.new
      generator = Doc::Generator.new program, ["foo"], ".", "html", nil
      doc_type = Doc::Type.new generator, program

      a_macro = Macro.new "foo"
      a_macro.location = Location.new "bar", 1, 1
      program.add_macro a_macro

      generator.must_include_toplevel?(doc_type).should be_false
    end

    it "returns true if program has method" do
      program = Program.new
      generator = Doc::Generator.new program, ["foo"], ".", "html", nil
      doc_type = Doc::Type.new generator, program

      a_def = Def.new "foo"
      a_def.location = Location.new "foo", 1, 1
      program.add_def a_def

      generator.must_include_toplevel?(doc_type).should be_true
    end

    it "returns false if program has method which is defined in other place" do
      program = Program.new
      generator = Doc::Generator.new program, ["foo"], ".", "html", nil
      doc_type = Doc::Type.new generator, program

      a_def = Def.new "foo"
      a_def.location = Location.new "bar", 1, 1
      program.add_def a_def

      generator.must_include_toplevel?(doc_type).should be_false
    end
  end

  describe "collect_constants" do
    it "returns empty array when constants are private" do
      program = Program.new
      generator = Doc::Generator.new program, ["foo"], ".", "html", nil
      doc_type = Doc::Type.new generator, program

      constant = Const.new program, program, "Foo", 1.int32
      constant.private = true
      constant.add_location Location.new "foo", 1, 1
      program.types[constant.name] = constant

      generator.collect_constants(doc_type).should be_empty
    end
  end
end
