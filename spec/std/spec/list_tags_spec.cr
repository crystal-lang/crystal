require "./spec_helper"

describe Spec do
  describe "list_tags" do
    it "lists the count of all tags", tags: %w[slow] do
      compile_and_run_source(<<-CRYSTAL, flags: %w(--no-debug), runtime_args: %w(--list-tags))[1].lines.should eq <<-OUT.lines
        require "spec"

        it "untagged #1" do
        end
        it "untagged #2" do
        end
        it "untagged #3" do
        end
      
        it "slow #1", tags: "slow" do
        end
        it "slow #2", tags: "slow" do
        end
      
        it "untagged #4" do
        end
      
        it "flakey #1", tags: "flakey" do
        end
        it "flakey #2, slow #3", tags: ["flakey", "slow"] do
        end
      
        it "untagged #5" do
        end
      
        pending "untagged #6"
      
        pending "untagged #7" do
        end
      
        pending "slow #5", tags: "slow"

        describe "describe specs", tags: "describe" do
          it "describe #1" do
          end
          it "describe #2" do
          end
          it "describe #3, slow #4", tags: "slow" do
          end
          it "describe #4, flakey #3", tags: "flakey" do
          end
        end
        CRYSTAL
        untagged: 7
            slow: 5
        describe: 4
          flakey: 3
        OUT
    end

    it "lists the count of slow tags", tags: %w[slow] do
      compile_and_run_source(<<-CRYSTAL, flags: %w(--no-debug), runtime_args: %w(--list-tags --tag slow))[1].lines.should eq <<-OUT.lines
        require "spec"

        it "untagged #1" do
        end
        it "untagged #2" do
        end
        it "untagged #3" do
        end
      
        it "slow #1", tags: "slow" do
        end
        it "slow #2", tags: "slow" do
        end
      
        it "untagged #4" do
        end
      
        it "flakey #1", tags: "flakey" do
        end
        it "flakey #2, slow #3", tags: ["flakey", "slow"] do
        end
      
        it "untagged #5" do
        end
      
        pending "untagged #6"
      
        pending "untagged #7" do
        end

        pending "slow #5", tags: "slow"
      
        describe "describe specs", tags: "describe" do
          it "describe #1" do
          end
          it "describe #2" do
          end
          it "describe #3, slow #4", tags: "slow" do
          end
          it "describe #4, flakey #3", tags: "flakey" do
          end
        end
        CRYSTAL
            slow: 5
        describe: 1
          flakey: 1
        OUT
    end

    it "does nothing if there are no examples", tags: %w[slow] do
      compile_and_run_source(<<-CRYSTAL, flags: %w(--no-debug), runtime_args: %w(--list-tags))[1].lines.should eq <<-OUT.lines
        require "spec"

        describe "describe specs", tags: "describe" do
        end
        CRYSTAL
        OUT
    end
  end
end
