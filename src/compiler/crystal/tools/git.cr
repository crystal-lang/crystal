module Crystal::Git
  class_property executable = "git"

  # Tries to run git command with args.
  # Yields block if exec fails or process status is not success.
  def self.git_command(args, output : Process::Stdio = Process::Redirect::Close)
    Process.run(executable, args, output: output).success?
  rescue IO::Error
    false
  end

  def self.git_capture(args)
    String.build do |io|
      git_command(args, output: io) || return
    end
  end

  def self.git_config(key)
    git_capture(["config", "--get", key]).try(&.strip).presence
  end
end
