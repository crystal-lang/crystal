require "spec"
require "./spec_helper"

private def yield_to(fiber)
  Crystal::Scheduler.enqueue(Fiber.current)
  Crystal::Scheduler.resume(fiber)
end

private macro parallel(*jobs)
  %channel = Channel(Exception | Nil).new

  {% for job, i in jobs %}
    %ret{i} = uninitialized typeof({{job}})
    spawn do
      begin
        %ret{i} = {{job}}
      rescue e : Exception
        %channel.send e
      else
        %channel.send nil
      end
    end
  {% end %}

  {{ jobs.size }}.times do
    %value = %channel.receive
    if %value.is_a?(Exception)
      raise Exception.new(
        "An unhandled error occurred inside a `parallel` call",
        cause: %value
      )
    end
  end

  {
    {% for job, i in jobs %}
      %ret{i},
    {% end %}
  }
end

describe Channel do
  it "creates unbuffered with no arguments" do
    Channel(Int32).new
  end

  it "creates buffered with capacity argument" do
    Channel(Int32).new(32)
  end

  it "send returns channel" do
    channel = Channel(Int32).new(1)
    channel.send(1).should be(channel)
  end

  it "does receive_first" do
    channel = Channel(Int32).new(1)
    channel.send(1)
    Channel.receive_first(Channel(Int32).new, channel).should eq 1
  end

  it "does send_first" do
    ch1 = Channel(Int32).new(1)
    ch2 = Channel(Int32).new(1)
    ch1.send(1)
    Channel.send_first(2, ch1, ch2)
    ch2.receive.should eq 2
  end

  it "does not raise or change its status when it is closed more than once" do
    ch = Channel(Int32).new
    ch.closed?.should be_false

    ch.close
    ch.closed?.should be_true

    ch.close
    ch.closed?.should be_true
  end

  describe ".select" do
    context "receive raise-on-close single-channel" do
      it "types" do
        ch = Channel(String).new
        spawn_and_wait(->{ ch.send "foo" }) do
          i, m = Channel.select(ch.receive_select_action)
          typeof(i).should eq(Int32)
          typeof(m).should eq(String)
        end
      end

      it "types nilable channel" do
        # Yes, although it is discouraged
        ch = Channel(Nil).new
        spawn_and_wait(->{ ch.send nil }) do
          i, m = Channel.select(ch.receive_select_action)
          typeof(i).should eq(Int32)
          typeof(m).should eq(Nil)
        end
      end

      it "raises if channel was closed" do
        ch = Channel(String).new
        spawn_and_wait(->{ ch.close }) do
          expect_raises Channel::ClosedError do
            Channel.select(ch.receive_select_action)
          end
        end
      end

      it "raises if channel is closed while waiting" do
        ch = Channel(String).new
        spawn_and_wait(->{ sleep 0.2; ch.close }) do
          expect_raises Channel::ClosedError do
            Channel.select(ch.receive_select_action)
          end
        end
      end

      it "awakes all waiting selects" do
        ch = Channel(String).new

        p = ->{
          begin
            Channel.select(ch.receive_select_action)
            0
          rescue Channel::ClosedError
            1
          end
        }

        spawn_and_wait(->{ sleep 0.2; ch.close }) do
          r = parallel p.call, p.call, p.call, p.call
          r.should eq({1, 1, 1, 1})
        end
      end
    end

    context "receive raise-on-close multi-channel" do
      it "types" do
        ch = Channel(String).new
        ch2 = Channel(Bool).new
        spawn_and_wait(->{ ch.send "foo" }) do
          i, m = Channel.select(ch.receive_select_action, ch2.receive_select_action)
          typeof(i).should eq(Int32)
          typeof(m).should eq(String | Bool)
        end
      end
    end

    context "receive nil-on-close single-channel" do
      it "types" do
        ch = Channel(String).new
        spawn_and_wait(->{ ch.send "foo" }) do
          i, m = Channel.select(ch.receive_select_action?)
          typeof(i).should eq(Int32)
          typeof(m).should eq(String | Nil)
        end
      end

      it "types nilable channel" do
        # Yes, although it is discouraged
        ch = Channel(Nil).new
        spawn_and_wait(->{ ch.send nil }) do
          i, m = Channel.select(ch.receive_select_action?)
          typeof(i).should eq(Int32)
          typeof(m).should eq(Nil)
        end
      end

      it "returns nil if channel was closed" do
        ch = Channel(String).new
        spawn_and_wait(->{ ch.close }) do
          i, m = Channel.select(ch.receive_select_action?)
          m.should be_nil
        end
      end

      it "returns nil channel is closed while waiting" do
        ch = Channel(String).new
        spawn_and_wait(->{ sleep 0.2; ch.close }) do
          i, m = Channel.select(ch.receive_select_action?)
          m.should be_nil
        end
      end

      it "awakes all waiting selects" do
        ch = Channel(String).new

        p = ->{
          Channel.select(ch.receive_select_action?)
        }

        spawn_and_wait(->{ sleep 0.2; ch.close }) do
          r = parallel p.call, p.call, p.call, p.call
          r.should eq({ {0, nil}, {0, nil}, {0, nil}, {0, nil} })
        end
      end
    end

    context "receive nil-on-close multi-channel" do
      it "types" do
        ch = Channel(String).new
        ch2 = Channel(Bool).new
        spawn_and_wait(->{ ch.send "foo" }) do
          i, m = Channel.select(ch.receive_select_action?, ch2.receive_select_action?)
          typeof(i).should eq(Int32)
          typeof(m).should eq(String | Bool | Nil)
        end
      end

      it "returns index of closed channel" do
        ch = Channel(String).new
        ch2 = Channel(Bool).new
        spawn_and_wait(->{ ch2.close }) do
          i, m = Channel.select(ch.receive_select_action?, ch2.receive_select_action?)
          i.should eq(1)
          m.should eq(nil)
        end
      end
    end

    context "mix of receive and receive? multi-channel" do
      it "raises if receive channel was closed and receive? channel was not ready" do
        ch = Channel(String).new
        ch2 = Channel(String).new
        spawn_and_wait(->{ ch.close }) do
          expect_raises Channel::ClosedError do
            Channel.select(ch.receive_select_action, ch2.receive_select_action?)
          end
        end
      end

      it "returns nil if receive channel was not ready and receive? channel was closed" do
        ch = Channel(String).new
        ch2 = Channel(String).new
        spawn_and_wait(->{ ch2.close }) do
          i, m = Channel.select(ch.receive_select_action, ch2.receive_select_action?)
          i.should eq(1)
          m.should eq(nil)
        end
      end
    end

    context "send raise-on-close single-channel" do
      it "types" do
        ch = Channel(String).new
        spawn_and_wait(->{ ch.receive }) do
          i, m = Channel.select(ch.send_select_action("foo"))
          typeof(i).should eq(Int32)
          typeof(m).should eq(Nil)
        end
      end

      it "types nilable channel" do
        # Yes, although it is discouraged
        ch = Channel(Nil).new
        spawn_and_wait(->{ ch.receive }) do
          i, m = Channel.select(ch.send_select_action(nil))
          typeof(i).should eq(Int32)
          typeof(m).should eq(Nil)
        end
      end

      it "raises if channel was closed" do
        ch = Channel(String).new
        spawn_and_wait(->{ ch.close }) do
          expect_raises Channel::ClosedError do
            Channel.select(ch.send_select_action("foo"))
          end
        end
      end

      it "raises if channel is closed while waiting" do
        ch = Channel(String).new
        spawn_and_wait(->{ sleep 0.2; ch.close }) do
          expect_raises Channel::ClosedError do
            Channel.select(ch.send_select_action("foo"))
          end
        end
      end

      it "awakes all waiting selects" do
        ch = Channel(String).new

        p = ->{
          begin
            Channel.select(ch.send_select_action("foo"))
            0
          rescue Channel::ClosedError
            1
          end
        }

        spawn_and_wait(->{ sleep 0.2; ch.close }) do
          r = parallel p.call, p.call, p.call, p.call
          r.should eq({1, 1, 1, 1})
        end
      end
    end

    context "send raise-on-close multi-channel" do
      it "types" do
        ch = Channel(String).new
        ch2 = Channel(Bool).new
        spawn_and_wait(->{ ch.receive }) do
          i, m = Channel.select(ch.send_select_action("foo"), ch2.send_select_action(true))
          typeof(i).should eq(Int32)
          typeof(m).should eq(Nil)
        end
      end
    end

    context "timeout" do
      it "types" do
        ch = Channel(String).new
        spawn_and_wait(->{ ch.send "foo" }) do
          i, m = Channel.select(ch.receive_select_action, timeout_select_action(0.1.seconds))
          typeof(i).should eq(Int32)
          typeof(m).should eq(String?)
        end
      end

      it "triggers timeout" do
        ch = Channel(String).new
        spawn_and_wait(->{}) do
          i, m = Channel.select(ch.receive_select_action, timeout_select_action(0.1.seconds))

          i.should eq(1)
          m.should eq(nil)
        end
      end

      it "triggers timeout (reverse order)" do
        ch = Channel(String).new
        spawn_and_wait(->{}) do
          i, m = Channel.select(timeout_select_action(0.1.seconds), ch.receive_select_action)

          i.should eq(0)
          m.should eq(nil)
        end
      end

      it "triggers timeout (same fiber multiple times)" do
        ch = Channel(String).new
        spawn_and_wait(->{}) do
          3.times do
            i, m = Channel.select(ch.receive_select_action, timeout_select_action(0.1.seconds))

            i.should eq(1)
            m.should eq(nil)
          end
        end
      end

      it "allows receiving while waiting" do
        ch = Channel(String).new
        spawn_and_wait(->{ ch.send "foo" }) do
          i, m = Channel.select(ch.receive_select_action, timeout_select_action(1.seconds))
          i.should eq(0)
          m.should eq("foo")
        end
      end

      it "allows receiving while waiting (reverse order)" do
        ch = Channel(String).new
        spawn_and_wait(->{ ch.send "foo" }) do
          i, m = Channel.select(timeout_select_action(1.seconds), ch.receive_select_action)
          i.should eq(1)
          m.should eq("foo")
        end
      end

      it "allows receiving while waiting (same fiber multiple times)" do
        ch = Channel(String).new
        spawn_and_wait(->{ 3.times { ch.send "foo" } }) do
          3.times do
            i, m = Channel.select(ch.receive_select_action, timeout_select_action(1.seconds))
            i.should eq(0)
            m.should eq("foo")
          end
        end
      end

      it "negative amounts should not trigger timeout" do
        ch = Channel(String).new
        spawn_and_wait(->{ ch.send "foo" }) do
          i, m = Channel.select(ch.receive_select_action, timeout_select_action(-1.seconds))

          i.should eq(0)
          m.should eq("foo")
        end
      end

      it "send raise-on-close raises if channel was closed while waiting" do
        ch = Channel(String).new
        spawn_and_wait(->{ ch.close }) do
          expect_raises Channel::ClosedError do
            Channel.select(ch.send_select_action("foo"), timeout_select_action(0.1.seconds))
          end
        end
      end

      it "receive raise-on-close raises if channel was closed while waiting" do
        ch = Channel(String).new
        spawn_and_wait(->{ ch.close }) do
          expect_raises Channel::ClosedError do
            Channel.select(ch.receive_select_action, timeout_select_action(0.1.seconds))
          end
        end
      end

      it "receive nil-on-close returns index of closed while waiting" do
        ch = Channel(String).new
        spawn_and_wait(->{ ch.close }) do
          i, m = Channel.select(ch.receive_select_action?, timeout_select_action(0.1.seconds))

          i.should eq(0)
          m.should eq(nil)
        end
      end
    end
  end

  describe ".non_blocking_select" do
    context "receive raise-on-close single-channel" do
      it "types" do
        ch = Channel(String).new
        spawn_and_wait(->{ ch.send "foo" }) do
          i, m = Channel.non_blocking_select(ch.receive_select_action)
          typeof(i).should eq(Int32)
          typeof(m).should eq(String | Channel::NotReady)
        end
      end
    end

    context "receive raise-on-close multi-channel" do
      it "types" do
        ch = Channel(String).new
        ch2 = Channel(Bool).new
        spawn_and_wait(->{ ch.send "foo" }) do
          i, m = Channel.non_blocking_select(ch.receive_select_action, ch2.receive_select_action)
          typeof(i).should eq(Int32)
          typeof(m).should eq(String | Bool | Channel::NotReady)
        end
      end
    end

    context "receive nil-on-close single-channel" do
      it "types" do
        ch = Channel(String).new
        spawn_and_wait(->{ ch.send "foo" }) do
          i, m = Channel.non_blocking_select(ch.receive_select_action?)
          typeof(i).should eq(Int32)
          typeof(m).should eq(String | Nil | Channel::NotReady)
        end
      end

      it "returns nil if channel was closed" do
        ch = Channel(String).new
        spawn_and_wait(->{ ch.close }) do
          i, m = Channel.non_blocking_select(ch.receive_select_action?)
          m.should be_nil
        end
      end
    end

    context "mix of receive and receive? multi-channel" do
      it "raises if receive channel was close and receive? channel was not ready" do
        ch = Channel(String).new
        ch2 = Channel(String).new

        spawn_and_wait(->{ ch.close }) do
          expect_raises Channel::ClosedError do
            Channel.non_blocking_select(ch.receive_select_action, ch2.receive_select_action?)
          end
        end
      end

      it "returns nil if receive channel was not ready and receive? channel was closed" do
        ch = Channel(String).new
        ch2 = Channel(String).new
        spawn_and_wait(->{ ch2.close }) do
          i, m = Channel.non_blocking_select(ch.receive_select_action, ch2.receive_select_action?)
          i.should eq(1)
          m.should eq(nil)
        end
      end
    end

    context "send raise-on-close single-channel" do
      it "types" do
        ch = Channel(String).new
        spawn_and_wait(->{ ch.receive }) do
          i, m = Channel.non_blocking_select(ch.send_select_action("foo"))
          typeof(i).should eq(Int32)
          typeof(m).should eq(Nil | Channel::NotReady)
        end
      end
    end

    context "send raise-on-close multi-channel" do
      it "types" do
        ch = Channel(String).new
        ch2 = Channel(Bool).new
        spawn_and_wait(->{ ch.receive }) do
          i, m = Channel.non_blocking_select(ch.send_select_action("foo"), ch2.send_select_action(true))
          typeof(i).should eq(Int32)
          typeof(m).should eq(Nil | Channel::NotReady)
        end
      end
    end

    context "timeout" do
      it "types" do
        ch = Channel(String).new
        spawn_and_wait(->{ ch.send "foo" }) do
          i, m = Channel.non_blocking_select(ch.receive_select_action, timeout_select_action(0.1.seconds))
          typeof(i).should eq(Int32)
          typeof(m).should eq(String | Nil | Channel::NotReady)
        end
      end

      it "should not trigger timeout" do
        ch = Channel(String).new
        spawn_and_wait(->{}) do
          i, m = Channel.non_blocking_select(ch.receive_select_action, timeout_select_action(0.1.seconds))

          i.should eq(2)
          m.should eq(Channel::NotReady.new)
        end
      end

      it "negative amounts should not trigger timeout" do
        ch = Channel(String).new
        spawn_and_wait(->{}) do
          i, m = Channel.non_blocking_select(ch.receive_select_action, timeout_select_action(-1.seconds))

          i.should eq(2)
          m.should eq(Channel::NotReady.new)
        end
      end

      it "send raise-on-close raises if channel was closed while waiting" do
        ch = Channel(String).new
        spawn_and_wait(->{ ch.close }) do
          expect_raises Channel::ClosedError do
            Channel.non_blocking_select(ch.send_select_action("foo"), timeout_select_action(0.1.seconds))
          end
        end
      end

      it "receive raise-on-close raises if channel was closed while waiting" do
        ch = Channel(String).new
        spawn_and_wait(->{ ch.close }) do
          expect_raises Channel::ClosedError do
            Channel.non_blocking_select(ch.receive_select_action, timeout_select_action(0.1.seconds))
          end
        end
      end

      it "receive nil-on-close returns index of closed while waiting" do
        ch = Channel(String).new
        spawn_and_wait(->{ ch.close }) do
          i, m = Channel.non_blocking_select(ch.receive_select_action?, timeout_select_action(0.1.seconds))

          i.should eq(0)
          m.should eq(nil)
        end
      end
    end

    it "returns correct index for array argument" do
      ch = [Channel(String).new, Channel(String).new, Channel(String).new]
      channels = [ch[0], ch[2], ch[1]] # shuffle around to get non-sequential lock_object_ids
      spawn_and_wait(->{ channels[0].send "foo" }) do
        i, m = Channel.non_blocking_select(channels.map(&.receive_select_action))

        i.should eq(0)
        m.should eq("foo")
      end
    end
  end
end

describe "unbuffered" do
  it "pings" do
    ch = Channel(Int32).new
    spawn { ch.send(ch.receive) }
    ch.send 123
    ch.receive.should eq(123)
  end

  it "blocks if there is no receiver" do
    ch = Channel(Int32).new
    state = 0
    main = Fiber.current

    sender = Fiber.new do
      state = 1
      ch.send 123
      state = 2
    ensure
      yield_to(main)
    end

    yield_to(sender)
    state.should eq(1)
    ch.receive.should eq(123)
    state.should eq(1)

    sleep
    state.should eq(2)
  end

  it "deliver many senders" do
    ch = Channel(Int32).new
    spawn { ch.send 1; ch.send 4 }
    spawn { ch.send 2; ch.send 5 }
    spawn { ch.send 3; ch.send 6 }

    (1..6).map { ch.receive }.sort!.should eq([1, 2, 3, 4, 5, 6])
  end

  it "works with select" do
    ch1 = Channel(Int32).new
    ch2 = Channel(Int32).new
    spawn { ch1.send 123 }
    Channel.select(ch1.receive_select_action, ch2.receive_select_action).should eq({0, 123})
  end

  it "can send and receive nil" do
    ch = Channel(Nil).new
    sender = Fiber.new { ch.send nil }
    yield_to(sender)
    ch.receive.should be_nil
  end

  it "can be closed" do
    ch = Channel(Int32).new
    ch.closed?.should be_false
    ch.close.should be_true
    ch.closed?.should be_true
    ch.close.should be_false
    expect_raises(Channel::ClosedError) { ch.receive }
  end

  it "can be closed after sending" do
    ch = Channel(Int32).new
    spawn { ch.send 123; ch.close }
    ch.receive.should eq(123)
    expect_raises(Channel::ClosedError) { ch.receive }
  end

  it "can be closed from different fiber" do
    ch = Channel(Int32).new
    closed = false
    main = Fiber.current

    receiver = Fiber.new do
      expect_raises(Channel::ClosedError) { ch.receive }
      closed = true
    ensure
      yield_to(main)
    end

    yield_to(receiver)
    ch.close

    sleep
    closed.should be_true
  end

  it "cannot send if closed" do
    ch = Channel(Int32).new
    ch.close
    expect_raises(Channel::ClosedError) { ch.send 123 }
  end

  it "can receive? when closed" do
    ch = Channel(Int32).new
    ch.close
    ch.receive?.should be_nil
  end

  it "can receive? when not empty" do
    ch = Channel(Int32).new
    spawn { ch.send 123 }
    ch.receive?.should eq(123)
  end

  it "wakes up sender fiber when channel is closed" do
    ch = Channel(Nil).new
    closed = false
    main = Fiber.current

    sender = Fiber.new do
      begin
        ch.send(nil)
      rescue Channel::ClosedError
        closed = true
      end
      yield_to(main)
    end

    yield_to(sender)

    ch.close
    sleep

    closed.should be_true
  end

  it "wakes up receiver fibers when channel is closed" do
    ch = Channel(Nil).new
    closed = false
    main = Fiber.current

    receiver = Fiber.new do
      ch.receive
    rescue Channel::ClosedError
      closed = ch.closed?
    ensure
      yield_to(main)
    end

    yield_to(receiver)

    ch.close
    sleep

    closed.should be_true
  end

  it "can send successfully without raise" do
    ch = Channel(Int32).new
    raise_flag = false

    sender = Fiber.new do
      ch.send 1
    rescue ex
      raise_flag = true
    end

    yield_to(sender)

    ch.receive.should eq(1)
    ch.close

    Fiber.yield

    raise_flag.should be_false
  end
end

describe "buffered" do
  it "pings" do
    ch = Channel(Int32).new(10)
    spawn { ch.send(ch.receive) }
    ch.send 123
    ch.receive.should eq(123)
  end

  it "blocks when full" do
    ch = Channel(Int32).new(2)
    done = false
    f = spawn { 5.times { |i| ch.send i }; done = true }

    ch.receive
    done.should be_false

    ch.receive
    done.should be_false

    # after the third receive, since the buffer is 2
    # f should be able to exec fully
    ch.receive
    wait_until_finished f
    done.should be_true
  end

  it "doesn't block when not full" do
    ch = Channel(Int32).new(10)
    done = false
    sender = Fiber.new { ch.send 123; done = true }
    yield_to(sender)
    done.should be_true
  end

  it "gets ready with data" do
    ch = Channel(Int32).new(10)
    ch.send 123
    ch.receive.should eq(123)
  end

  it "works with select" do
    ch1 = Channel(Int32).new(10)
    ch2 = Channel(Int32).new(10)
    spawn { ch1.send 123 }
    Channel.select(ch1.receive_select_action, ch2.receive_select_action).should eq({0, 123})
  end

  it "can send and receive nil" do
    ch = Channel(Nil).new(10)
    sender = Fiber.new { ch.send nil }
    yield_to(sender)
    ch.receive.should be_nil
  end

  it "can be closed" do
    ch = Channel(Int32).new(10)
    ch.closed?.should be_false
    ch.close
    ch.closed?.should be_true
    expect_raises(Channel::ClosedError) { ch.receive }
  end

  it "can be closed after sending" do
    ch = Channel(Int32).new(10)
    ch.send 123
    ch.close
    ch.receive.should eq(123)
    expect_raises(Channel::ClosedError) { ch.receive }
  end

  it "can be closed from different fiber" do
    ch = Channel(Int32).new(10)
    received = false
    main = Fiber.current

    receiver = Fiber.new do
      expect_raises(Channel::ClosedError) { ch.receive }
      received = true
    ensure
      yield_to(main)
    end

    yield_to(receiver)
    ch.close
    sleep
    received.should be_true
  end

  it "cannot send if closed" do
    ch = Channel(Int32).new(10)
    ch.close
    expect_raises(Channel::ClosedError) { ch.send 123 }
  end

  it "can receive? when closed" do
    ch = Channel(Int32).new(10)
    ch.close
    ch.receive?.should be_nil
  end

  it "can receive? when not empty" do
    ch = Channel(Int32).new(10)
    spawn { ch.send 123 }
    ch.receive?.should eq(123)
  end

  it "can send successfully without raise" do
    ch = Channel(Int32).new(1)
    raise_flag = false

    sender = Fiber.new do
      ch.send 1
      ch.send 2
    rescue ex
      raise_flag = true
    end

    yield_to(sender)

    ch.receive.should eq(1)
    ch.receive.should eq(2)
    ch.close

    Fiber.yield

    raise_flag.should be_false
  end

  it "does inspect on unbuffered channel" do
    ch = Channel(Int32).new
    ch.inspect.should eq("#<Channel(Int32):0x#{ch.object_id.to_s(16)}>")
  end

  it "does inspect on buffered channel" do
    ch = Channel(Int32).new(10)
    ch.inspect.should eq("#<Channel(Int32):0x#{ch.object_id.to_s(16)}>")
  end

  it "does pretty_inspect on unbuffered channel" do
    ch = Channel(Int32).new
    ch.pretty_inspect.should eq("#<Channel(Int32):0x#{ch.object_id.to_s(16)}>")
  end

  it "does pretty_inspect on buffered channel" do
    ch = Channel(Int32).new(10)
    ch.pretty_inspect.should eq("#<Channel(Int32):0x#{ch.object_id.to_s(16)}>")
  end
end
