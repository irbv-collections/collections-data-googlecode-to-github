require 'thor'

module VascanDataGooglecodeToGithub
  module Cli
    class Application < Thor
      desc "dryrun", "test and output result as text"
      method_option :token, :type => :string, :required => :true, :desc => "GitHub access TOKEN"
      method_option :input, :type => :string, :required => :true, :desc => "GoogleCode INPUT json file"
      def dryrun()
        Migrator.new.dryrun(options[:token], options[:input])
      end
      
      desc "inspect", "Inspect the GoogleCode json document"
      method_option :input, :type => :string, :required => :true, :desc => "GoogleCode INPUT json file"
      def inspect()
        Migrator.new.inspect(options[:input])
      end
      
    end
  end
end