module Crystal::Doc
  record ProjectInfo, name : String, version : String do
    def self.new_with_defaults(name, version)
      version ||= find_git_version

      unless name && version
        shard_name, shard_version = read_shard_properties
        name ||= shard_name
        version ||= shard_version

        unless name && version
          return yield name, version
        end
      end

      new(name, version)
    end

    def self.find_git_version
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
      versions = tags.select(&.starts_with?("v"))
      # Only accept when there's exactly one version tag pointing at HEAD.
      if versions.size == 1
        return versions.first.byte_slice(1)
      end
    end

    def self.read_shard_properties
      return {nil, nil} unless File.readable?("shard.yml")

      name = nil
      version = nil

      # Poor man's YAML reader
      File.each_line("shard.yml") do |line|
        if name.nil? && line.starts_with?("name:")
          end_pos = line.byte_index("#") || line.bytesize
          name = line.byte_slice(5, end_pos - 5).strip.strip(%("'))
        elsif version.nil? && line.starts_with?("version:")
          end_pos = line.byte_index("#") || line.bytesize
          version = line.byte_slice(8, end_pos - 8).strip.strip(%("'))
        elsif version && name
          break
        end
      end

      return name.presence, version.presence
    end
  end
end
