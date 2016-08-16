# Implementation of the `crystal deps` command, which
# simply delegates to the `shards` executable

class Crystal::Command
  private def deps
    path_to_shards = `which shards`.chomp
    if path_to_shards.empty?
      error "`shards` executable is missing. Please install shards: https://github.com/ysbaddaden/shards"
    end

    status = Process.run(path_to_shards, args: options, output: true, error: true)
    exit status.exit_code unless status.success?
  end
end
