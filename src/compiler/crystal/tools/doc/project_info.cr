module Crystal::Doc
  record ProjectInfo, name : String, version : String do
    def self.find_default_version
      # Use git to determine if index and working directory are clean
      io = IO::Memory.new
      status = Process.run("git", ["status", "--porcelain"], output: io)
      # If clean, output of `git status --porcelain` is empty. Still need to check
      # the status code, to make sure empty doesn't mean error.
      io.rewind
      return unless status.success? && io.bytesize == 0

      # Check if current HEAD is tagged
      status = Process.run("git", ["tag", "--points-at", "HEAD"], output: io)
      return unless status.success?
      io.rewind
      tags = io.to_s.lines
      # Only accept when there's exactly one tag pointing at HEAD.
      if tags.size == 1
        tags.first
      end
    end
  end
end
