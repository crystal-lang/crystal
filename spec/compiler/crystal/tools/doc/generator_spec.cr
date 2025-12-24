require "../../../spec_helper"

private ANNOTATION_COLORS = {"Deprecated" => "red", "Experimental" => "lime"}

describe Doc::Generator do
  describe "#must_include_toplevel?" do
    it "returns false if program has nothing" do
      program = Program.new
      generator = Doc::Generator.new program, ["foo"]
      doc_type = Doc::Type.new generator, program

      generator.must_include_toplevel?(doc_type).should be_false
    end

    it "returns true if program has constant" do
      program = Program.new
      generator = Doc::Generator.new program, ["foo"]
      doc_type = Doc::Type.new generator, program

      constant = Const.new program, program, "Foo", 1.int32
      constant.add_location Location.new "foo", 1, 1
      program.types[constant.name] = constant

      generator.must_include_toplevel?(doc_type).should be_true
    end

    it "returns false if program has constant which is defined in other place" do
      program = Program.new
      generator = Doc::Generator.new program, ["foo"]
      doc_type = Doc::Type.new generator, program

      constant = Const.new program, program, "Foo", 1.int32
      constant.add_location Location.new "bar", 1, 1
      program.types[constant.name] = constant

      generator.must_include_toplevel?(doc_type).should be_false
    end

    it "returns true if program has macro" do
      program = Program.new
      generator = Doc::Generator.new program, ["foo"]
      doc_type = Doc::Type.new generator, program

      a_macro = Macro.new "foo"
      a_macro.location = Location.new "foo", 1, 1
      program.add_macro a_macro

      generator.must_include_toplevel?(doc_type).should be_true
    end

    it "returns false if program has macro which is defined in other place" do
      program = Program.new
      generator = Doc::Generator.new program, ["foo"]
      doc_type = Doc::Type.new generator, program

      a_macro = Macro.new "foo"
      a_macro.location = Location.new "bar", 1, 1
      program.add_macro a_macro

      generator.must_include_toplevel?(doc_type).should be_false
    end

    it "returns true if program has method" do
      program = Program.new
      generator = Doc::Generator.new program, ["foo"]
      doc_type = Doc::Type.new generator, program

      a_def = Def.new "foo"
      a_def.location = Location.new "foo", 1, 1
      program.add_def a_def

      generator.must_include_toplevel?(doc_type).should be_true
    end

    it "returns false if program has method which is defined in other place" do
      program = Program.new
      generator = Doc::Generator.new program, ["foo"]
      doc_type = Doc::Type.new generator, program

      a_def = Def.new "foo"
      a_def.location = Location.new "bar", 1, 1
      program.add_def a_def

      generator.must_include_toplevel?(doc_type).should be_false
    end
  end

  describe "#collect_constants" do
    it "returns empty array when constants are private" do
      program = Program.new
      generator = Doc::Generator.new program, ["foo"]
      doc_type = Doc::Type.new generator, program

      constant = Const.new program, program, "Foo", 1.int32
      constant.private = true
      constant.add_location Location.new "foo", 1, 1
      program.types[constant.name] = constant

      generator.collect_constants(doc_type).should be_empty
    end
  end

  describe "#formatted_summary" do
    ANNOTATION_COLORS.each do |ann, color|
      describe "with a #{ann} annotation, and no docs" do
        it "should generate just the #{ann} tag" do
          program = Program.new
          generator = Doc::Generator.new program, ["."]
          doc_type = Doc::Type.new generator, program

          a_def = Def.new "foo"
          a_def.add_annotation(program.types[ann].as(Crystal::AnnotationType), Crystal::Annotation.new(Crystal::Path.new(ann), ["lorem ipsum".string] of ASTNode))
          doc_method = Doc::Method.new generator, doc_type, a_def, false
          doc_method.formatted_summary.should eq %(<p><span class="flag #{color}">#{ann.upcase}</span>  lorem ipsum</p>)
        end
      end

      describe "with a #{ann} annotation, and docs" do
        it "should generate both the docs and #{ann} tag" do
          program = Program.new
          generator = Doc::Generator.new program, ["."]
          doc_type = Doc::Type.new generator, program

          a_def = Def.new "foo"
          a_def.doc = "Some Method"
          a_def.add_annotation(program.types[ann].as(Crystal::AnnotationType), Crystal::Annotation.new(Crystal::Path.new(ann), ["lorem ipsum".string] of ASTNode))
          doc_method = Doc::Method.new generator, doc_type, a_def, false
          doc_method.formatted_summary.should eq %(<p>Some Method</p>\n<p><span class="flag #{color}">#{ann.upcase}</span>  lorem ipsum</p>)
        end
      end
    end

    describe "with no annotation, and no docs" do
      it "should generate nothing" do
        program = Program.new
        generator = Doc::Generator.new program, ["."]
        doc_type = Doc::Type.new generator, program

        a_def = Def.new "foo"
        doc_method = Doc::Method.new generator, doc_type, a_def, false
        doc_method.formatted_summary.should be_nil
      end
    end

    it "should generate the first sentence" do
      program = Program.new
      generator = Doc::Generator.new program, ["."]
      doc_type = Doc::Type.new generator, program

      a_def = Def.new "foo"
      a_def.doc = "Some Method.  Longer description"
      doc_method = Doc::Method.new generator, doc_type, a_def, false
      doc_method.formatted_summary.should eq %(<p>Some Method.</p>)
    end

    it "should generate the first line" do
      program = Program.new
      generator = Doc::Generator.new program, ["."]
      doc_type = Doc::Type.new generator, program

      a_def = Def.new "foo"
      a_def.doc = "Some Method\n\nMore Data"
      doc_method = Doc::Method.new generator, doc_type, a_def, false
      doc_method.formatted_summary.should eq %(<p>Some Method</p>)
    end

    it "should exclude whitespace before the summary line" do
      program = Program.new
      generator = Doc::Generator.new program, ["."]
      doc_type = Doc::Type.new generator, program

      a_def = Def.new "foo"
      a_def.doc = " \n\nSome Method\n\nMore Data"
      doc_method = Doc::Method.new generator, doc_type, a_def, false
      doc_method.formatted_summary.should eq %(<p>Some Method</p>)
    end
  end

  describe "#formatted_doc" do
    ANNOTATION_COLORS.each do |ann, color|
      describe "with a #{ann} annotation, and no docs" do
        it "should generate just the #{ann} tag" do
          program = Program.new
          generator = Doc::Generator.new program, ["."]
          doc_type = Doc::Type.new generator, program

          a_def = Def.new "foo"
          a_def.add_annotation(program.types[ann].as(Crystal::AnnotationType), Crystal::Annotation.new(Crystal::Path.new(ann), ["lorem ipsum".string] of ASTNode))
          doc_method = Doc::Method.new generator, doc_type, a_def, false
          doc_method.formatted_doc.should eq %(<p><span class="flag #{color}">#{ann.upcase}</span>  lorem ipsum</p>)
        end
      end

      describe "with a #{ann} annotation, and docs" do
        it "should generate both the docs and #{ann} tag" do
          program = Program.new
          generator = Doc::Generator.new program, ["."]
          doc_type = Doc::Type.new generator, program

          a_def = Def.new "foo"
          a_def.doc = "Some Method"
          a_def.add_annotation(program.types[ann].as(Crystal::AnnotationType), Crystal::Annotation.new(Crystal::Path.new(ann), ["lorem ipsum".string] of ASTNode))
          doc_method = Doc::Method.new generator, doc_type, a_def, false
          doc_method.formatted_doc.should eq %(<p>Some Method</p>\n<p><span class="flag #{color}">#{ann.upcase}</span>  lorem ipsum</p>)
        end
      end

      describe "with alias" do
        it "should generate the #{ann} tag" do
          program = Program.new
          generator = Doc::Generator.new program, ["."]

          alias_type = AliasType.new(program, program, "Foo", Crystal::Path.new("Bar"))
          alias_type.add_annotation(program.types[ann].as(Crystal::AnnotationType), Crystal::Annotation.new(Crystal::Path.new(ann), ["lorem ipsum".string] of ASTNode))
          doc_type = Doc::Type.new generator, alias_type
          doc_type.formatted_doc.should eq %(<p><span class="flag #{color}">#{ann.upcase}</span>  lorem ipsum</p>)
        end
      end

      describe "with #{ann} annotation in parameter" do
        it "should generate the #{ann} tag" do
          program = Program.new
          generator = Doc::Generator.new program, ["."]
          doc_type = Doc::Type.new generator, program

          a_def = Def.new "foo"
          a_def.doc = "Some Method"
          arg = Arg.new("bar")
          arg.add_annotation(program.types[ann].as(Crystal::AnnotationType), Crystal::Annotation.new(Crystal::Path.new(ann), ["lorem ipsum".string] of ASTNode))
          a_def.args << arg
          doc_method = Doc::Method.new generator, doc_type, a_def, false
          doc_method.formatted_doc.should eq %(<p>Some Method</p>\n<p><span class="flag #{color}">#{ann.upcase} parameter <code>bar</code></span>  lorem ipsum</p>)
        end
      end
    end

    describe "with no annotation, and no docs" do
      it "should generate nothing" do
        program = Program.new
        generator = Doc::Generator.new program, ["."]
        doc_type = Doc::Type.new generator, program

        a_def = Def.new "foo"
        doc_method = Doc::Method.new generator, doc_type, a_def, false
        doc_method.formatted_doc.should be_nil
      end
    end

    it "should generate the full document" do
      program = Program.new
      generator = Doc::Generator.new program, ["."]
      doc_type = Doc::Type.new generator, program

      a_def = Def.new "foo"
      a_def.doc = "Some Method.  Longer description"
      doc_method = Doc::Method.new generator, doc_type, a_def, false
      doc_method.formatted_doc.should eq %(<p>Some Method.  Longer description</p>)
    end

    it "should generate the full document" do
      program = Program.new
      generator = Doc::Generator.new program, ["."]
      doc_type = Doc::Type.new generator, program

      a_def = Def.new "foo"
      a_def.doc = "Some Method\n\nMore Data"
      doc_method = Doc::Method.new generator, doc_type, a_def, false
      doc_method.formatted_doc.should eq %(<p>Some Method</p>\n<p>More Data</p>)
    end
  end

  describe "crystal repo" do
    it "inserts pseudo methods" do
      program = Program.new
      generator = Doc::Generator.new program, ["."]
      doc_type = Doc::Type.new generator, program
      generator.project_info.name = "Crystal"

      pseudo_def = Def.new "__crystal_pseudo_typeof"
      pseudo_def.doc = "Foo"
      doc_method = Doc::Method.new generator, doc_type, pseudo_def, false
      doc_method.name.should eq "typeof"
      doc_method.doc.not_nil!.should contain %(NOTE: This is a pseudo-method)

      regular_def = Def.new "pseudo_bar"
      regular_def.doc = "Foo"
      doc_method = Doc::Method.new generator, doc_type, regular_def, false
      doc_method.name.should eq "pseudo_bar"
      doc_method.doc.not_nil!.should_not contain %(NOTE: This is a pseudo-method)
    end
  end

  it "generates sitemap" do
    program = Program.new
    generator = Doc::Generator.new program, ["."]
    doc_type = Doc::Type.new generator, program

    Doc::SitemapTemplate.new([doc_type], "http://example.com/api/1.0", "0.8", "monthly").to_s.should eq <<-XML
      <?xml version="1.0" encoding="UTF-8"?>
      <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
        <url>
          <loc>http://example.com/api/1.0/toplevel.html</loc>
          <priority>0.8</priority>
          <changefreq>monthly</changefreq>
        </url>
      </urlset>

      XML
  end
end
