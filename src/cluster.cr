class Cluster

    def self.fork (env : Hash)
        env["FORKED"] = "1"
        return Process.fork { Process.run(PROGRAM_NAME, nil, env, true, false, true, true, true, nil ) }
    end

    def self.isMaster
        (ENV["FORKED"] ||= "0") == "0"
    end

    def self.isSlave
        (ENV["FORKED"] ||= "0") == "1"
    end

    def self.getEnv (env : String)
        ENV[env] ||= ""
    end
    
end
