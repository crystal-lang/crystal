require "./spec_helper"

describe Spec do
  describe "hooks" do
    it "runs in correct order", tags: %w[slow] do
      compile_and_run_source(<<-CRYSTAL, flags: %w(--no-debug))[1].lines[..-5].should eq <<-OUT.lines
        require "prelude"
        require "spec"

        begin
          before_all {}
        rescue exc
          puts exc.message
        end
        begin
          before_each {}
        rescue exc
          puts exc.message
        end
        begin
          after_all {}
        rescue exc
          puts exc.message
        end
        begin
          after_each {}
        rescue exc
          puts exc.message
        end
        begin
          around_all {}
        rescue exc
          puts exc.message
        end
        begin
          around_each {}
        rescue exc
          puts exc.message
        end

        Spec.before_suite { puts "Spec:before_suite" }
        Spec.before_each { puts "Spec:before_each" }
        Spec.after_suite { puts "Spec:after_all" }
        Spec.after_each { puts "Spec:after_each" }
        Spec.around_each do |example|
          puts "Spec:around_each:before"
          example.run
          puts "Spec:around_each:after"
        end

        describe "foo" do
          before_all { puts "foo:before_all" }
          before_each { puts "foo:before_each" }
          after_all { puts "foo:after_all" }
          after_each { puts "foo:after_each" }
          around_all do |example|
            puts "foo:around_all:before"
            example.run
            puts "foo:around_all:after"
          end
          around_each do |example|
            puts "foo:around_each:before"
            example.run
            puts "foo:around_each:after"
          end

          it {}
          it {}

          describe "foofoo" do
            it {}
          end
        end

        describe "bar" do
          before_all { puts "bar:before_all" }
          before_each { puts "bar:before_each" }
          after_all { puts "bar:after_all" }
          after_each { puts "bar:after_each" }
          around_all do |example|
            puts "bar:around_all:before"
            example.run
            puts "bar:around_all:after"
          end
          around_each do |example|
            puts "bar:around_each:before"
            example.run
            puts "bar:around_each:after"
          end

          it {}
        end
        CRYSTAL
        Can't call `before_all` outside of a describe/context
        Can't call `before_each` outside of a describe/context
        Can't call `after_all` outside of a describe/context
        Can't call `after_each` outside of a describe/context
        Can't call `around_all` outside of a describe/context
        Can't call `around_each` outside of a describe/context
        Spec:before_suite
        foo:around_all:before
        foo:before_all
        Spec:around_each:before
        foo:around_each:before
        Spec:before_each
        foo:before_each
        .foo:after_each
        Spec:after_each
        foo:around_each:after
        Spec:around_each:after
        Spec:around_each:before
        foo:around_each:before
        Spec:before_each
        foo:before_each
        .foo:after_each
        Spec:after_each
        foo:around_each:after
        Spec:around_each:after
        Spec:around_each:before
        foo:around_each:before
        Spec:before_each
        foo:before_each
        .foo:after_each
        Spec:after_each
        foo:around_each:after
        Spec:around_each:after
        foo:after_all
        foo:around_all:after
        bar:around_all:before
        bar:before_all
        Spec:around_each:before
        bar:around_each:before
        Spec:before_each
        bar:before_each
        .bar:after_each
        Spec:after_each
        bar:around_each:after
        Spec:around_each:after
        bar:after_all
        bar:around_all:after
        Spec:after_all
        OUT
    end
  end
end
