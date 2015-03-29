lib LibC
  fun tmpfile : File

  ifdef darwin || linux
    fun mkstemp(result : UInt8*) : Int32
  end
end

class Tempfile < FileDescriptorIO
  def initialize(name)
    ifdef darwin || linux
      if tmpdir = ENV["TMPDIR"]?
        tmpdir = tmpdir + '/' unless tmpdir.ends_with? '/'
      else
        tmpdir = "/tmp/"
      end
      @path = "#{tmpdir}#{name}.XXXXXX"
      super(LibC.mkstemp(@path))
    elsif windows
      @path = ""
      super(LibC.fileno(LibC.tmpfile))
    end
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
    ifdef darwin || linux
      File.delete(@path)
    elsif windows
      0
    end
  end

  def unlink
    delete
  end
end
