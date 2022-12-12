module Crystal::Doc
  class ProjectInfo
    property! name : String
    property! version : String
    property json_config_url : String? = nil
    property refname : String? = nil
    property source_url_pattern : String? = nil
    property canonical_base_url : String? = nil

    def initialize(@name : String? = nil, @version : String? = nil, @refname : String? = nil, @source_url_pattern : String? = nil)
    end

    def_equals_and_hash @name, @version, @json_config_url, @refname, @source_url_pattern

    def crystal_stdlib?
      name == "Crystal"
    end

    def fill_with_defaults
      unless version?
        if git_version = ProjectInfo.find_git_version
          self.version = git_version
        end
      end

      if ProjectInfo.git_clean?
        self.refname ||= ProjectInfo.git_ref(branch: false)
      end

      unless source_url_pattern
        if remote = ProjectInfo.git_remote
          self.source_url_pattern = ProjectInfo.find_source_url_pattern(remote)
        end
      end

      unless name? && version?
        shard_name, shard_version = ProjectInfo.read_shard_properties
        if shard_name && !name?
          self.name = shard_name
        end
        if shard_version && !version?
          self.version = shard_version
        end
      end
    end

    def source_url(location : RelativeLocation)
      refname = self.refname
      url_pattern = source_url_pattern

      return unless refname && url_pattern

      url = url_pattern % {refname: refname, path: location.filename, filename: File.basename(location.filename), line: location.line_number}
      url.presence
    end

    VERSION_TAG = /^v(\d+[-.][-.a-zA-Z\d]+)$/

    def self.find_git_version
      if ref = git_ref(branch: true)
        if ref.matches?(VERSION_TAG)
          ref = ref.byte_slice(1)
        end

        unless git_clean?
          ref = "#{ref}-dev"
        end

        ref
      end
    end

    def self.find_source_url_pattern(remote)
      if (at_index = remote.index('@')) && (colon_index = remote.index(':')) && at_index < colon_index
        # SSH URI
        host = remote[(at_index + 1)...colon_index]
        path = remote[(colon_index + 1)..]
      else
        begin
          uri = URI.parse(remote)
        rescue URI::Error
          return
        end
        host = uri.host
        path = uri.path
      end

      path = path.strip("/")

      case host
      when "github.com", "www.github.com"
        # GitHub only resolves URLs with the canonical repo name without .git extension.
        path = path.rchop(".git")
        "https://github.com/#{path}/blob/%{refname}/%{path}#L%{line}"
      when "gitlab.com", "www.gitlab.com"
        # GitLab only resolves URLs with the canonical repo name without .git extension.
        path = path.rchop(".git")
        "https://gitlab.com/#{path}/blob/%{refname}/%{path}#L%{line}"
      when "bitbucket.com", "www.bitbucket.com"
        # Bitbucket does resolve URLs the URL with .git extension, but without it
        # the canonical form and should be preferred.
        path = path.rchop(".git")
        "https://bitbucket.com/#{path}/src/%{refname}/%{path}#%{filename}-%{line}"
      when "git.sr.ht"
        # On git.sr.ht ~foo/bar and ~foo/bar.git seem to mean different repos.
        "https://git.sr.ht/#{path}/tree/%{refname}/%{path}#L%{line}"
      else
        # Unknown remote host, can't determine source url pattern
      end
    end

    def self.git_remote
      # check whether inside git work-tree
      Crystal::Git.git_command(["rev-parse", "--is-inside-work-tree"]) || return

      capture = Crystal::Git.git_capture(["remote", "-v"]) || return
      remotes = capture.lines.select(&.ends_with?(" (fetch)"))

      git_remote = remotes.find(&.starts_with?("origin\t")) || remotes.first? || return

      start_pos = git_remote.index("\t")
      end_pos = git_remote.rindex(" ")
      return unless start_pos && end_pos
      git_remote[(start_pos + 1)...end_pos].presence
    end

    def self.git_clean?
      # Use git to determine if index and working directory are clean
      # In case the command failed to execute or returned error status, return false
      capture = Crystal::Git.git_capture(["status", "--porcelain", "--untracked-files=no"]) || return false

      # Index is clean if output is empty (and program status is success, checked by git_capture)
      capture.bytesize == 0
    end

    def self.git_ref(*, branch)
      # Check if current HEAD is tagged
      capture = Crystal::Git.git_capture(["tag", "--points-at", "HEAD"]) || return
      tags = capture.lines
      # Return tag if commit is tagged, select first one if multiple
      if tag = tags.first?
        return tag
      end

      if branch
        # Read current branch name
        capture = Crystal::Git.git_capture(["rev-parse", "--abbrev-ref", "HEAD"]) || return

        if branch_name = capture.strip.presence
          return branch_name
        end
      end

      # Otherwise, return current commit sha
      capture = Crystal::Git.git_capture(["rev-parse", "HEAD"]) || return

      if sha = capture.strip.presence
        return sha
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
