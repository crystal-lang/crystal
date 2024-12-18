require "./spec_helper"

module Reply
  ENTRIES = [
    [%(puts "Hello World")],
    [%(i = 0)],
    [
      %(while i < 10),
      %(  puts i),
      %(  i += 1),
      %(end),
    ],
  ]

  describe History do
    it "submits entry" do
      history = SpecHelper.history

      history.verify([] of Array(String), index: 0)

      history << [%(puts "Hello World")]
      history.verify(ENTRIES[0...1], index: 1)

      history << [%(i = 0)]
      history.verify(ENTRIES[0...2], index: 2)

      history << [
        %(while i < 10),
        %(  puts i),
        %(  i += 1),
        %(end),
      ]
      history.verify(ENTRIES, index: 3)
    end

    it "submit duplicate entry" do
      history = SpecHelper.history(with: ENTRIES)

      history.verify(ENTRIES, index: 3)

      history << [%(i = 0)]
      history.verify([ENTRIES[0], ENTRIES[2], ENTRIES[1]], index: 3)
    end

    it "clears" do
      history = SpecHelper.history(with: ENTRIES)

      history.clear
      history.verify([] of Array(String), index: 0)
    end

    it "navigates" do
      history = SpecHelper.history(with: ENTRIES)

      history.verify(ENTRIES, index: 3)

      # Before down: current edition...
      # After down: current edition...
      history.down(["current edition..."]).should be_nil
      history.verify(ENTRIES, index: 3)

      # Before up: current edition...
      # After up: while i < 10
      #  puts i
      #  i += 1
      # end
      history.up(["current edition..."]).should eq ENTRIES[2]
      history.verify(ENTRIES, index: 2)

      # Before up: while i < 10
      #  puts i
      #  i += 1
      # end
      # After up: i = 0
      history.up(ENTRIES[2]).should eq ENTRIES[1]
      history.verify(ENTRIES, index: 1)

      # Before up (edited): edited_i = 0
      # After up: puts "Hello World"
      history.up([%(edited_i = 0)]).should eq ENTRIES[0]
      history.verify(ENTRIES, index: 0)

      # Before up: puts "Hello World"
      # After up: puts "Hello World"
      history.up(ENTRIES[0]).should be_nil
      history.verify(ENTRIES, index: 0)

      # Before down: puts "Hello World"
      # After down: edited_i = 0
      history.down(ENTRIES[0]).should eq [%(edited_i = 0)]
      history.verify(ENTRIES, index: 1)

      # Before down down: edited_i = 0
      # After down down: current edition...
      history.down([%(edited_i = 0)]).should eq ENTRIES[2]
      history.down(ENTRIES[2]).should eq [%(current edition...)]
      history.verify(ENTRIES, index: 3)
    end

    it "saves and loads" do
      entries = ([
        [%(foo)],
        [%q(\)],
        [
          %q(bar),
          %q("baz" \),
          %q("\n\\"),
          %q(),
          %q(\),
        ],
        [%q(a\\\b)],
      ])
      history = SpecHelper.history(with: entries)

      io = IO::Memory.new
      history.save(io)
      io.to_s.should eq(
        %q(foo) + "\n" +
        %q(\\) + "\n" +
        %q(bar\) + "\n" +
        %q("baz" \\\) + "\n" +
        %q("\\n\\\\"\) + "\n" +
        %q(\) + "\n" +
        %q(\\) + "\n" +
        %q(a\\\\\\b)
      )

      io.rewind
      history.load(io)

      history.verify(entries, index: 4)
    end

    it "saves and loads empty" do
      history = SpecHelper.history

      io = IO::Memory.new
      history.save(io)
      io.to_s.should be_empty

      io.rewind
      history.load(io)

      history.verify([] of Array(String), index: 0)
    end

    it "respects max size" do
      history = SpecHelper.history

      history.max_size = 4

      history << ["1"]
      history << ["2"]
      history << ["3"]
      history << ["4"]
      history.verify([["1"], ["2"], ["3"], ["4"]], index: 4)

      history << ["5"]
      history.verify([["2"], ["3"], ["4"], ["5"]], index: 4)

      history.max_size = 2
      history << ["6"]
      history.verify([["5"], ["6"]], index: 2)

      history.max_size = 0 # minimum possible is 1
      history << ["7"]
      history.verify([["7"]], index: 1)

      history.max_size = -314 # minimum possible is 1
      history << ["8"]
      history.verify([["8"]], index: 1)

      history.max_size = 3
      history << ["9"]
      history.verify([["8"], ["9"]], index: 2)
    end
  end
end
