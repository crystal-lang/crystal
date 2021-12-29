require "./lib_wasi"

module Crystal::System::Wasi
  PREOPENS = begin
    preopens = [] of {String, String, LibWasi::Fd}

    # Skip stdin, stdout, and stderr, and count up until we reach an invalid file descriptor.
    (3..).each do |fd|
      stat = uninitialized LibWasi::Prestat
      err = LibWasi.fd_prestat_get(fd, pointerof(stat))

      break unless err.success?

      next unless stat.tag.dir?

      len = stat.value.dir.pr_name_len

      name = String.new(len + 1) do |buffer|
        err = LibWasi.fd_prestat_dir_name(fd, buffer, len)
        raise RuntimeError.from_os_error("fd_prestat_dir_name", err) unless err.success?
        buffer[len] = 0
        len = LibC.strlen(buffer)
        {len, 0}
      end

      path = ::Path[name].expand.to_s
      preopens << {path, path.ends_with?("/") ? path : path + "/", fd}
    end

    # Preopens added later take priority over preopens added earlier.
    preopens.reverse!
    # Preopens of longer prefix take priority over shorter prefixes.
    preopens.sort_by! { |entry| -entry[0].size }

    preopens
  end

  def self.find_path_preopen(path)
    path = ::Path[path].expand.to_s
    PREOPENS.each do |preopen|
      case path
      when preopen[0]
        return {preopen[2], "."}
      when .starts_with? preopen[1]
        return {preopen[2], path[preopen[1].size..-1]}
      end
    end

    # If we can't find a preopen for it, indicate that we lack capabilities.
    raise RuntimeError.from_os_error(nil, WasiError::NOTCAPABLE)
  end
end
