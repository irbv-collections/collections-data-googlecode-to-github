require 'thor'

module VascanDataGooglecodeToGithub
  module Cli
    class Application < Thor
      desc "dryrun", "test and output result as text"
      def dryrun(googleCodeJSONExportFile)
        Migrator.new.dryrun(googleCodeJSONExportFile)
      end
      desc "inspect", "Inspect the GoogleCode json document"
      def inspect(googleCodeJSONExportFile)
        Migrator.new.inspect(googleCodeJSONExportFile)
      end
      
    end
  end
end