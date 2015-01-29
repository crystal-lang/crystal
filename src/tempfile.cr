lib LibC
  fun mkstemp(result : UInt8*) : Int32
end

class Tempfile < FileDescriptorIO
  def initialize(name)
    if tmpdir = ENV["TMPDIR"]?
      tmpdir = tmpdir + '/' unless tmpdir.ends_with? '/'
    else
      tmpdir = "/tmp/"
    end
    @path = "#{tmpdir}#{name}.XXXXXX"
    super(LibC.mkstemp(@path))
  end

  getter path

  def self.open(filename)
    tempfile = Tempfile.new(filename)
    begin
      yield tempfile
    ensure
      tempfile.close
    end
    tempfile
  end

  def delete
    File.delete(@path)
  end

  def unlink
    delete
  end
end
