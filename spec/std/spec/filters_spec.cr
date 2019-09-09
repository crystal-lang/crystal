require "./spec_helper"

module Spec::Item
  setter focus : Bool
  setter tags : Set(String)?
end

describe Spec::RootContext do
  describe "#run_filters" do
    describe "by pattern" do
      it "on an example" do
        root = build_spec("f.cr")
        root.run_filters(pattern: /example_f_2_2/)
        all_spec_descriptions(root).should eq %w[root context_f_2 example_f_2_2]
      end

      it "on a context" do
        root = build_spec("f.cr")
        root.run_filters(pattern: /context_f_2/)
        all_spec_descriptions(root).should eq %w[root context_f_2 example_f_2_1 example_f_2_2]
      end
    end

    describe "by line" do
      it "on a context's start line'" do
        root = build_spec("f.cr")
        root.run_filters(line: 11)
        all_spec_descriptions(root).should eq %w[root context_f_2 example_f_2_1 example_f_2_2]
      end

      it "between examples" do
        root = build_spec("f.cr")
        root.run_filters(line: 15)
        all_spec_descriptions(root).should eq %w[root context_f_2 example_f_2_1 example_f_2_2]
      end

      it "on an example's start line" do
        root = build_spec("f.cr")
        root.run_filters(line: 16)
        all_spec_descriptions(root).should eq %w[root context_f_2 example_f_2_2]
      end

      it "in an example" do
        root = build_spec("f.cr")
        root.run_filters(line: 17)
        all_spec_descriptions(root).should eq %w[root context_f_2 example_f_2_2]
      end

      it "on an example's end line" do
        root = build_spec("f.cr")
        root.run_filters(line: 18)
        all_spec_descriptions(root).should eq %w[root context_f_2 example_f_2_2]
      end

      it "on a context's end line'" do
        root = build_spec("f.cr")
        root.run_filters(line: 19)
        all_spec_descriptions(root).should eq %w[root context_f_2 example_f_2_1 example_f_2_2]
      end
    end

    describe "by locations" do
      it "on a context's start line'" do
        root = build_spec("f.cr")
        root.run_filters(locations: {"f.cr" => [11]})
        all_spec_descriptions(root).should eq %w[root context_f_2 example_f_2_1 example_f_2_2]
      end

      it "between examples" do
        root = build_spec("f.cr")
        root.run_filters(locations: {"f.cr" => [15]})
        all_spec_descriptions(root).should eq %w[root context_f_2 example_f_2_1 example_f_2_2]
      end

      it "on an example's start line" do
        root = build_spec("f.cr")
        root.run_filters(locations: {"f.cr" => [16]})
        all_spec_descriptions(root).should eq %w[root context_f_2 example_f_2_2]
      end

      it "in an example" do
        root = build_spec("f.cr")
        root.run_filters(locations: {"f.cr" => [17]})
        all_spec_descriptions(root).should eq %w[root context_f_2 example_f_2_2]
      end

      it "on an example's end line" do
        root = build_spec("f.cr")
        root.run_filters(locations: {"f.cr" => [18]})
        all_spec_descriptions(root).should eq %w[root context_f_2 example_f_2_2]
      end

      it "on a context's end line'" do
        root = build_spec("f.cr")
        root.run_filters(locations: {"f.cr" => [19]})
        all_spec_descriptions(root).should eq %w[root context_f_2 example_f_2_1 example_f_2_2]
      end
    end

    describe "by focus" do
      it "on an example" do
        root = build_spec("f.cr")
        root.children[1].as(Spec::ExampleGroup).children[1].as(Spec::Example).focus = true
        root.run_filters(focus: true)
        all_spec_descriptions(root).should eq %w[root context_f_2 example_f_2_2]
      end

      it "on a context" do
        root = build_spec("f.cr")
        root.children[1].as(Spec::ExampleGroup).focus = true
        root.run_filters(focus: true)
        all_spec_descriptions(root).should eq %w[root context_f_2 example_f_2_1 example_f_2_2]
      end
    end

    describe "by tags" do
      it "on an example" do
        root = build_spec("f.cr")
        root.children[1].as(Spec::ExampleGroup).children[1].as(Spec::Example).tags = Set{"fast"}
        root.run_filters(tags: Set{"fast"})
        all_spec_descriptions(root).should eq %w[root context_f_2 example_f_2_2]
      end

      it "on a context" do
        root = build_spec("f.cr")
        root.children[1].as(Spec::ExampleGroup).tags = Set{"fast"}
        root.run_filters(tags: Set{"fast"})
        all_spec_descriptions(root).should eq %w[root context_f_2 example_f_2_1 example_f_2_2]
      end
    end

    describe "by anti_tags" do
      it "on an example" do
        root = build_spec("f.cr")
        root.children[0].as(Spec::ExampleGroup).children[0].as(Spec::Example).tags = Set{"slow"}
        root.children[0].as(Spec::ExampleGroup).children[1].as(Spec::Example).tags = Set{"slow"}
        root.run_filters(anti_tags: Set{"slow"})
        all_spec_descriptions(root).should eq %w[root context_f_2 example_f_2_1 example_f_2_2]
      end

      it "on a context" do
        root = build_spec("f.cr")
        root.children[0].as(Spec::ExampleGroup).tags = Set{"slow"}
        root.run_filters(anti_tags: Set{"slow"})
        all_spec_descriptions(root).should eq %w[root context_f_2 example_f_2_1 example_f_2_2]
      end
    end
  end
end
