require "fileutils"

module AiHubWorker
  class DefinitionCache
    def initialize(path)
      @path = path
      FileUtils.mkdir_p(@path, mode: 0o700)
    end

    def fetch(digest)
      path = File.join(@path, "#{digest}.json")
      return JSON.parse(File.read(path)) if File.exist?(path)

      definition = yield
      raise "Definition digest mismatch" unless definition.fetch("digest") == digest

      temporary = "#{path}.#{Process.pid}.tmp"
      File.write(temporary, JSON.generate(definition), mode: "w", perm: 0o600)
      File.rename(temporary, path)
      definition
    end
  end
end
