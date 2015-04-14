require 'thor'

module VascanDataGooglecodeToGithub
  module Cli
    class Application < Thor
      desc "dryrun", "test and output result as text"
      method_option :token, :type => :string, :required => :true, :desc => "GitHub access TOKEN"
      method_option :input, :type => :string, :required => :true, :desc => "GoogleCode INPUT json file"
      method_option :write_gc_author, :type => :boolean, :default => false, :desc => "Should we include the original GoogleCode author name in GitHub issue description"
      def dryrun()
        Migrator.new.dryrun(options[:token], options[:input], options[:write_gc_author])
      end
      
      desc "upload", "run and upload issues/comments to GitHub"
      method_option :token, :type => :string, :required => :true, :desc => "GitHub access TOKEN"
      method_option :input, :type => :string, :required => :true, :desc => "GoogleCode INPUT json file"
      method_option :write_gc_author, :type => :boolean, :default => false, :desc => "Should we include the original GoogleCode author name in GitHub issue description"
      def upload()
        Migrator.new.run(options[:token], options[:input], options[:write_gc_author])
      end
      
      desc "inspect", "Inspect the GoogleCode json document"
      method_option :input, :type => :string, :required => :true, :desc => "GoogleCode INPUT json file"
      def inspect()
        Migrator.new.inspect(options[:input])
      end
      
      desc "inspect_states", "Inspect transfer state json document"
      def inspect_states()
        Migrator.new.inspect_states()
      end

      
    end
  end
end