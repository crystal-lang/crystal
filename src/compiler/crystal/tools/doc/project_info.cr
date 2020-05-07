module Crystal::Doc
  class ProjectInfo
    property! name : String
    property! version : String
    property json_config_url : String? = nil

    def initialize(@name : String? = nil, @version : String? = nil)
    end

    def_equals_and_hash @name, @version, @json_config_url

    def crystal_stdlib?
      name == "Crystal"
    end

    def fill_with_defaults
      unless version?
        if git_version = ProjectInfo.find_git_version
          self.version = git_version
        end
      end

      unless name? && version?
        shard_name, shard_version = ProjectInfo.read_shard_properties
        if shard_name && !name?
          self.name = shard_name
        end
        if shard_version && !version? && !ProjectInfo.git_dir?
          self.version = shard_version
        end
      end
    end

    def self.git_dir?
      Process.run("git", ["rev-parse", "--is-inside-work-tree"]).success?
    end

    VERSION_TAG = /^v(\d+[-.][-.a-zA-Z\d]+)$/

    def self.find_git_version
      if ref = git_ref
        if ref.matches?(VERSION_TAG)
          ref = ref.byte_slice(1)
        end

        unless git_clean?
          ref = "#{ref}-dev"
        end

        ref
      end
    end

    def self.git_clean?
      # Use git to determine if index and working directory are clean
      io = IO::Memory.new
      status = Process.run("git", ["status", "--porcelain"], output: io)
      # If clean, output of `git status --porcelain` is empty. Still need to check
      # the status code, to make sure empty doesn't mean error.
      return unless status.success?
      io.rewind
      io.bytesize == 0
    end

    def self.git_ref
      io = IO::Memory.new
      # Check if current HEAD is tagged
      status = Process.run("git", ["tag", "--points-at", "HEAD"], output: io)
      return unless status.success?
      io.rewind
      tags = io.to_s.lines
      # Return tag if commit is tagged, select first one if multiple
      if tag = tags.first?
        return tag
      end

      # Otherwise, return current branch name
      io.clear
      status = Process.run("git", ["rev-parse", "--abbrev-ref", "HEAD"], output: io)
      return unless status.success?

      io.to_s.strip.presence
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
