require "spec"

describe Select do
  it "selects file descriptors" do
    IO.pipe do |reader, writer|
      writer.write_byte 10_u8

      run = false
      select
      when byte = reader.read_byte
        run = true
        byte.should eq(10_u8)
      end

      run.should be_true
    end

    IO.pipe do |reader, writer|
      select
      when writer.write_byte(11_u8)
      end

      reader.read_byte.should eq(11_u8)
    end
  end

  it "selects file descriptors with else" do
    IO.pipe do |reader, writer|
      writer.write_byte 10_u8

      select
      when byte = reader.read_byte
        byte.should eq(10_u8)
      else
        raise "Else Reached"
      end
    end

    IO.pipe do |reader, writer|
      spawn do
        sleep 20.milliseconds
        begin
          writer.write_byte 10_u8
        rescue ignored : IO::Error
          # write_byte will fail as the pipe is closed before 20ms
        end
      end

      else_run = false
      select
      when byte = reader.read_byte
        raise "Read byte"
      else
        else_run = true
      end

      else_run.should eq(true)
    end

    IO.pipe do |reader, writer|
      select
      when writer.write_byte(11_u8)
      end

      reader.read_byte.should eq(11_u8)
    end
  end

  it "selects events on the same channel (read)" do
    channel = Channel(Nil).new

    spawn { channel.send(nil) }

    receive = send = false
    select
    when channel.send(nil)
      send = true
    when channel.receive
      receive = true
    end

    receive.should be_true
    send.should be_false
  end

  it "selects events on the same channel (write)" do
    channel = Channel(Nil).new

    spawn { channel.receive }

    receive = send = false
    select
    when channel.receive
      receive = true
    when channel.send(nil)
      send = true
    end

    receive.should be_false
    send.should be_true
  end
end
