class Cluster

    def self.fork (env : Hash)
        env["FORKED"] = "1"
        Process.fork { Process.run(PROGRAM_NAME, nil, env, true, false, true, true, true, nil ) }
    end

    def self.master?
     (ENV["FORKED"]? || "0") == "0"
    end
  
    def self.worker?
     (ENV["FORKED"]? || "0") == "1"
    end

end
