require "vascan_data_googlecode_to_github/version"
require "vascan_data_googlecode_to_github/githubissue"
require "vascan_data_googlecode_to_github/cli/application"
require 'json'
require 'octokit'

module VascanDataGooglecodeToGithub

  class Migrator
    # label definitions
    GIT_HUB_REPO = "Canadensys/vascan-data"
    INCLUDE_LABELS = ['Vascan']
    EXCLUDE_LABELS = ['Section-BackEnd']

    #GoogleCode -> GitHub isssue label mapping 
    LABEL_MAPPING = {VernacularEN:"vernacularEN", VernacularFR:"vernacularFR"}
    
    #GoogleCode -> GitHub user mapping
    USER_MAPPING = {"luc.brouillet@umontreal.ca" => "brouille", "manions@natureserve.ca"=>"manions", "marilynanions"=>"manions","frederic.coursol"=>"FredCoursol"}
    
    def dryrun(googleCodeJSONExportFile)
      readGoogleCodeExportFile(googleCodeJSONExportFile)
    end
    
    # Inspect the GoogleCode json document according to the shouldInclude? function.
    def inspect(googleCodeJSONExportFile)
      authorHash = Hash.new(0)
      file = File.read(googleCodeJSONExportFile)
      data_hash = JSON.parse(file, :symbolize_names => true)
      data_hash[:projects][0][:issues][:items].each do |issue|
        if shouldInclude?(issue[:labels])
          authorHash[issue[:author][:name]] += 1;
        end
      end
      puts "#{authorHash.length} distinct authors:#{authorHash.inspect}"
    end
    
    def readGoogleCodeExportFile(googleCodeJSONExportFile)
      file = File.read(googleCodeJSONExportFile)
      data_hash = JSON.parse(file, :symbolize_names => true)
      data_hash[:projects][0][:issues][:items].each do |issue|
        if shouldInclude?(issue[:labels])
          convertToGitHubIssue(issue)
        end
      end
    end
    
    # Check if we should include the issue in the migration
    # if one label is in EXCLUDE_LABELS, this method immediately returns false
    def shouldInclude? (labels)
      if !(labels & EXCLUDE_LABELS).empty?
        return false
      end
      return !(labels & INCLUDE_LABELS).empty?
    end
    
    def convertToGitHubIssue (gcIssue)
      ghIssue = GitHubIssue.new
      ghIssue.title = gcIssue[:title]
      ghIssue.labels = gcIssue[:labels].collect { |label| LABEL_MAPPING[label.to_sym] }.compact
      ghIssue.user = USER_MAPPING[gcIssue[:author][:name]]
      
      #the body is actually the first comment
      #we should also trim template text like "(This is the template to report a data issue for Vascan. If you want to report another issue, please change the template above.)"
      #ghIssue.body = gcIssue[:summary]

      puts ghIssue.inspect
      # deal with comments
      #gcIssue[:comments][:items].each do |comment|
       # puts comment
      #end
    end
    
    private :readGoogleCodeExportFile, :shouldInclude?, :convertToGitHubIssue
  end
end
