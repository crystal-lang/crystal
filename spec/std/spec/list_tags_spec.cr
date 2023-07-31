require "./spec_helper"

describe Spec do
  describe "list_tags" do
    it "lists the count of all tags (including pending seperately)", tags: %w[slow] do
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
        tags:
        untagged: 5
            slow: 4
        describe: 4
          flakey: 3

        pending tags:
        untagged: 2
        OUT
    end

    it "lists the count of all tags (without any pending examples)", tags: %w[slow] do
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
        tags:
        untagged: 5
            slow: 4
        describe: 4
          flakey: 3
        OUT
    end

    it "lists the count of all tags (only pending)", tags: %w[slow] do
      compile_and_run_source(<<-CRYSTAL, flags: %w(--no-debug), runtime_args: %w(--list-tags))[1].lines.should eq <<-OUT.lines
        require "spec"

        pending "untagged #1"
        pending "untagged #2"
        pending "untagged #3"
      
        pending "slow #1", tags: "slow"
        pending "slow #2", tags: "slow"
      
        pending "untagged #4"
      
        pending "flakey #1", tags: "flakey"
        pending "flakey #2, slow #3", tags: ["flakey", "slow"]
      
        pending "untagged #5"
      
        pending "untagged #6"
      
        pending "untagged #7" do
        end
      
        describe "describe specs", tags: "describe" do
          pending "describe #1"
          pending "describe #2"
          pending "describe #3, slow #4", tags: "slow"
          pending "describe #4, flakey #3", tags: "flakey"
        end
        CRYSTAL
        pending tags:
        untagged: 7
            slow: 4
        describe: 4
          flakey: 3
        OUT
    end
  end
end
