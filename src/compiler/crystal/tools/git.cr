module Crystal::Git
  class_property executable = "git"

  # Tries to run git command with args.
  # Yields block if exec fails or process status is not success.
  def self.git_command(args, output : Process::Stdio = Process::Redirect::Close)
    status = Process.run(executable, args, output: output)
    yield unless status.success?
    status
  rescue IO::Error
    yield
  end

  def self.git_capture(args)
    String.build do |io|
      git_command(args, output: io) { yield }
    end
  end

  def self.git_config(key)
    git_capture(["config", "--get", key]) { nil }.presence
  end
end
