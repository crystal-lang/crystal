require "./spec_helper"

describe Spec do
  describe "expectations outside of an example or hook" do
    it "are rejected", tags: %w[slow] do
      compile_and_run_source(<<-CRYSTAL, flags: %w(--no-debug))[1].lines[..-4].should eq <<-OUT.lines
        require "prelude"
        require "spec"

        def check(&)
          yield
        rescue exc : Spec::OutsideExampleError
          puts exc.message
        end

        check { 1.should eq(1) }
        check { 1.should be_a(Int32) }
        check { 1.should_not eq(2) }
        check { 1.should_not be_a(String) }
        check { 1.should_not be_nil }

        Spec.before_suite { 1.should eq(1) }
        Spec.after_suite { 1.should eq(1) }
        Spec.before_each { 1.should eq(1) }
        Spec.after_each { 1.should eq(1) }

        describe "foo" do
          check { 1.should eq(1) }
          check { 1.should eq(2) }

          before_all { 1.should eq(1) }
          after_all { 1.should eq(1) }
          around_all do |example|
            1.should eq(1)
            example.run
          end

          before_each { 1.should eq(1) }
          after_each { 1.should eq(1) }
          around_each do |example|
            1.should eq(1)
            example.run
          end

          it { 1.should eq(1) }
        end
        CRYSTAL
        Can't call `should` outside of an example or hook
        Can't call `should` outside of an example or hook
        Can't call `should_not` outside of an example or hook
        Can't call `should_not` outside of an example or hook
        Can't call `should_not` outside of an example or hook
        Can't call `should` outside of an example or hook
        Can't call `should` outside of an example or hook
        .
        OUT
    end

    it "are allowed without the spec runner", tags: %w[slow] do
      compile_and_run_source(<<-CRYSTAL, flags: %w(--no-debug))[1].should eq "1\n"
        require "prelude"
        require "spec/dsl"

        puts 1.should eq(1)
        CRYSTAL
    end
  end
end
