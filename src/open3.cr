require "process"

module Open3
  def self.popen2(command, env = nil, pgroup = nil, umask = nil, &block)
    in_r, in_w = input = IO.pipe
    out_r, out_w = IO.pipe

    #popen_run(command, {in_r, out_w}, {in_w, out_r}, env, pgroup, umask, &block)
    popen_run(command, {in_r, out_w}, {in_w, out_r}, env, pgroup, umask) do |pid|
      yield in_w, out_r, pid
    end
  end

  def self.popen2e(command, env = nil, pgroup = nil, umask = nil, &block)
    in_r, in_w = IO.pipe
    out_r, out_w = IO.pipe

    #popen_run(command, {in_r, out_w, out_w}, {in_w, out_r}, env, pgroup, umask, &block)
    popen_run(command, {in_r, out_w, out_w}, {in_w, out_r}, env, pgroup, umask) do |pid|
      yield in_w, out_r, pid
    end
  end

  def self.popen3(command, env = nil, pgroup = nil, umask = nil, &block)
    in_r, in_w = IO.pipe
    out_r, out_w = IO.pipe
    err_r, err_w = IO.pipe

    #popen_run(command, {in_r, out_w, err_w}, {in_w, out_r, err_r}, env, pgroup, umask, &block)
    popen_run(command, {in_r, out_w, err_w}, {in_w, out_r, err_r}, env, pgroup, umask) do |wait_thr|
      yield in_w, out_r, err_r, wait_thr
    end
  end

  def self.capture2(command, stdin_data = "", env = nil, pgroup = nil, umask = nil)
    popen2(command, env, pgroup, umask) do |stdin, stdout, wait_thr|
      output, _error, status = capture(stdin_data, stdin, stdout, nil, wait_thr)
      {output.to_s, status}
    end
  end

  def self.capture2e(command, stdin_data = "", env = nil, pgroup = nil, umask = nil)
    popen2e(command, env, pgroup, umask) do |stdin, stdout_stderr, wait_thr|
      output, _error, status = capture(stdin_data, stdin, stdout_stderr, nil, wait_thr)
      {output.to_s, status}
    end
  end

  def self.capture3(command, stdin_data = "", env = nil, pgroup = nil, umask = nil)
    popen3(command, env, pgroup, umask) do |stdin, stdout, stderr, wait_thr|
      output, error, status = capture(stdin_data, stdin, stdout, stderr, wait_thr)
      {output.to_s, error.to_s, status}
    end
  end

  private def self.popen_run(command, child_io, parent_io, env = nil, pgroup = nil, umask = nil)
    pid = Process.spawn(command, env, *child_io, pgroup: pgroup, umask: umask)
    wait_thr = Thread.new { Process.waitpid(pid) }
    child_io.each { |io| io.close rescue nil }

    begin
      #yield(*parent_io, pid)
      yield wait_thr
    ensure
      parent_io.each { |io| io.close rescue nil }
    end
  end

  private def self.capture(stdin_data, stdin, stdout, stderr, wait_thr)
    output, error = StringIO.new, StringIO.new
    read = stderr ? {stdout, stderr} : {stdout}
    write = {stdin}

    buffer :: UInt8[2048]

    loop do
      ios = IO.select(read, write)

      if stdin && ios.includes?(stdin)
        stdin.print(stdin_data)
        stdin.close
        write = stdin = nil
      end

      if stdout && ios.includes?(stdout)
        bytes = stdout.read(buffer.to_slice)
        if bytes == 0
          stdout.close
          stdout = nil
          read = stderr ? {stderr} : nil
        end
        output.write(buffer.to_slice, bytes)
      end

      if stderr && ios.includes?(stderr)
        bytes = stderr.read(buffer.to_slice)
        if bytes == 0
          stderr.close
          stderr = nil
          read = stdout ? {stdout} : nil
        end
        error.write(buffer.to_slice, bytes)
      end

      break unless read || write
    end

    {output, error, wait_thr.join}
  end
end
