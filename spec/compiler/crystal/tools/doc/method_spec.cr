require "../../../spec_helper"

private def assert_args_to_s(item, to_s_output, to_html_output = to_s_output, *, file = __FILE__, line = __LINE__)
  item.args_to_s.should eq(to_s_output), file: file, line: line
  item.args_to_html.should eq(to_html_output), file: file, line: line
end

describe Doc::Method do
  describe "args_to_s" do
    it "shows simple args" do
      program = Program.new
      generator = Doc::Generator.new program, ["."]
      doc_type = Doc::Type.new generator, program

      a_def = Def.new "foo", ["foo".arg, "bar".arg]
      doc_method = Doc::Method.new generator, doc_type, a_def, false
      assert_args_to_s(doc_method, "(foo, bar)")
    end

    it "shows splat args" do
      program = Program.new
      generator = Doc::Generator.new program, ["."]
      doc_type = Doc::Type.new generator, program

      a_def = Def.new "foo", ["foo".arg], splat_index: 0
      doc_method = Doc::Method.new generator, doc_type, a_def, false
      assert_args_to_s(doc_method, "(*foo)")
    end

    it "shows underscore restriction" do
      program = Program.new
      generator = Doc::Generator.new program, ["."]
      doc_type = Doc::Type.new generator, program

      a_def = Def.new "foo", ["foo".arg(restriction: Crystal::Underscore.new)], splat_index: 0
      doc_method = Doc::Method.new generator, doc_type, a_def, false
      assert_args_to_s(doc_method, "(*foo : _)")
    end

    it "shows double splat args" do
      program = Program.new
      generator = Doc::Generator.new program, ["."]
      doc_type = Doc::Type.new generator, program

      a_def = Def.new "foo", double_splat: "foo".arg
      doc_method = Doc::Method.new generator, doc_type, a_def, false
      assert_args_to_s(doc_method, "(**foo)")
    end

    it "shows block args" do
      program = Program.new
      generator = Doc::Generator.new program, ["."]
      doc_type = Doc::Type.new generator, program

      a_def = Def.new "foo", block_arg: "foo".arg
      doc_method = Doc::Method.new generator, doc_type, a_def, false
      assert_args_to_s(doc_method, "(&foo)")
    end

    it "shows block args with underscore" do
      program = Program.new
      generator = Doc::Generator.new program, ["."]
      doc_type = Doc::Type.new generator, program

      a_def = Def.new "foo", block_arg: "foo".arg(restriction: Crystal::ProcNotation.new(([Crystal::Underscore.new] of Crystal::ASTNode), Crystal::Underscore.new))
      doc_method = Doc::Method.new generator, doc_type, a_def, false
      assert_args_to_s(doc_method, "(&foo : _ -> _)")
    end

    it "shows block args if a def has `yield`" do
      program = Program.new
      generator = Doc::Generator.new program, ["."]
      doc_type = Doc::Type.new generator, program

      a_def = Def.new "foo", block_arity: 1
      doc_method = Doc::Method.new generator, doc_type, a_def, false
      assert_args_to_s(doc_method, "(&)")
    end

    it "shows return type restriction" do
      program = Program.new
      generator = Doc::Generator.new program, ["."]
      doc_type = Doc::Type.new generator, program

      a_def = Def.new "foo", return_type: "Foo".path
      doc_method = Doc::Method.new generator, doc_type, a_def, false
      assert_args_to_s(doc_method, " : Foo")
    end

    it "shows args and return type restriction" do
      program = Program.new
      generator = Doc::Generator.new program, ["."]
      doc_type = Doc::Type.new generator, program

      a_def = Def.new "foo", ["foo".arg], return_type: "Foo".path
      doc_method = Doc::Method.new generator, doc_type, a_def, false
      assert_args_to_s(doc_method, "(foo) : Foo")
    end

    it "shows external name of arg" do
      program = Program.new
      generator = Doc::Generator.new program, ["."]
      doc_type = Doc::Type.new generator, program

      a_def = Def.new "foo", ["foo".arg(external_name: "bar")]
      doc_method = Doc::Method.new generator, doc_type, a_def, false
      assert_args_to_s(doc_method, "(bar foo)")
    end

    it "shows external name of arg with quotes and escaping" do
      program = Program.new
      generator = Doc::Generator.new program, ["."]
      doc_type = Doc::Type.new generator, program

      a_def = Def.new "foo", ["foo".arg(external_name: "<<-< uouo fish life")]
      doc_method = Doc::Method.new generator, doc_type, a_def, false
      assert_args_to_s(doc_method,
        %(("<<-< uouo fish life" foo)),
        "(&quot;&lt;&lt;-&lt; uouo fish life&quot; foo)")
    end

    it "shows typeof restriction of arg with highlighting" do
      program = Program.new
      generator = Doc::Generator.new program, ["."]
      doc_type = Doc::Type.new generator, program

      a_def = Def.new "foo", ["foo".arg(restriction: TypeOf.new([1.int32] of ASTNode))]
      doc_method = Doc::Method.new generator, doc_type, a_def, false
      assert_args_to_s(doc_method,
        %((foo : typeof(1))),
        %((foo : <span class="k">typeof</span>(<span class="n">1</span>))))
    end

    it "shows default value of arg with highlighting" do
      program = Program.new
      generator = Doc::Generator.new program, ["."]
      doc_type = Doc::Type.new generator, program

      a_def = Def.new "foo", ["foo".arg(default_value: 1.int32)]
      doc_method = Doc::Method.new generator, doc_type, a_def, false
      assert_args_to_s(doc_method, %((foo = 1)), %((foo = <span class="n">1</span>)))
    end
  end

  describe "doc" do
    it "gets doc from underlying method" do
      program = semantic("
        class Foo
          # Some docs
          def foo
          end
        end
        ", wants_doc: true).program
      generator = Doc::Generator.new program, [""]
      method = generator.type(program.types["Foo"]).lookup_method("foo").not_nil!
      method.doc.should eq("Some docs")
      method.doc_copied_from.should be_nil
    end

    it "trailing comment is not a doc comment" do
      program = semantic(<<-CRYSTAL, inject_primitives: false, wants_doc: true).program
        nil # trailing comment
        def foo
        end
        CRYSTAL
      generator = Doc::Generator.new program, [""]
      method = generator.type(program).lookup_class_method("foo").not_nil!
      method.doc.should be_nil
    end

    it "trailing comment is not part of a doc comment" do
      program = semantic(<<-CRYSTAL, inject_primitives: false, wants_doc: true).program
        nil # trailing comment
        # doc comment
        def foo
        end
        CRYSTAL
      generator = Doc::Generator.new program, [""]
      method = generator.type(program).lookup_class_method("foo").not_nil!
      method.doc.should eq("doc comment")
    end

    it "inherits doc from ancestor (no extra comment)" do
      program = semantic("
        class Foo
          # Some docs
          def foo
          end
        end

        class Bar < Foo
          def foo
            super
          end
        end
        ", wants_doc: true).program
      generator = Doc::Generator.new program, [""]
      method = generator.type(program.types["Bar"]).lookup_method("foo").not_nil!
      method.doc.should eq("Some docs")
      method.doc_copied_from.should eq(generator.type(program.types["Foo"]))
    end

    it "inherits doc from previous def (no extra comment)" do
      program = semantic("
        class Foo
          # Some docs
          def foo
          end

          def foo
            previous_def
          end
        end
        ", wants_doc: true).program
      generator = Doc::Generator.new program, [""]
      method = generator.type(program.types["Foo"]).lookup_method("foo").not_nil!
      method.doc.should eq("Some docs")
      method.doc_copied_from.should be_nil
    end

    it "inherits doc from ancestor (use :inherit:)" do
      program = semantic("
        class Foo
          # Some docs
          def foo
          end
        end

        class Bar < Foo
          # :inherit:
          def foo
            super
          end
        end
        ", wants_doc: true).program
      generator = Doc::Generator.new program, [""]
      method = generator.type(program.types["Bar"]).lookup_method("foo").not_nil!
      method.doc.should eq("Some docs")
      method.doc_copied_from.should be_nil
    end

    it "inherits doc from ancestor (use :inherit: plus more content)" do
      program = semantic("
        class Foo
          # Some docs
          def foo
          end
        end

        class Bar < Foo
          # Before
          #
          # :inherit:
          #
          # After
          def foo
            super
          end
        end
        ", wants_doc: true).program
      generator = Doc::Generator.new program, [""]
      method = generator.type(program.types["Bar"]).lookup_method("foo").not_nil!
      method.doc.should eq("Before\n\nSome docs\n\nAfter")
      method.doc_copied_from.should be_nil
    end
  end
end
