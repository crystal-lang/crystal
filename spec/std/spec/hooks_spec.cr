require "../../spec_helper"

describe Spec do
  describe "hooks" do
    it "runs in correct order" do
      run(<<-CR).to_string.lines[..-5].should eq <<-OUT.lines
        require "prelude"
        require "spec"

        before_all { puts "top:before_all" }
        before_each { puts "top:before_each" }
        after_all { puts "top:after_all" }
        after_each { puts "top:after_each" }
        around_each do |example|
          puts "top:around_each:before"
          example.run
          puts "top:around_each:after"
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
        CR
        top:before_all
        foo:around_all:before
        foo:before_all
        top:around_each:before
        foo:around_each:before
        top:before_each
        foo:before_each
        .foo:after_each
        top:after_each
        foo:around_each:after
        top:around_each:after
        top:around_each:before
        foo:around_each:before
        top:before_each
        foo:before_each
        .foo:after_each
        top:after_each
        foo:around_each:after
        top:around_each:after
        top:around_each:before
        foo:around_each:before
        top:before_each
        foo:before_each
        .foo:after_each
        top:after_each
        foo:around_each:after
        top:around_each:after
        foo:after_all
        foo:around_all:after
        bar:around_all:before
        bar:before_all
        top:around_each:before
        bar:around_each:before
        top:before_each
        bar:before_each
        .bar:after_each
        top:after_each
        bar:around_each:after
        top:around_each:after
        bar:after_all
        bar:around_all:after
        top:after_all
        OUT
    end
  end
end
