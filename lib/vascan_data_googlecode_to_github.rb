require "vascan_data_googlecode_to_github/version"
require "vascan_data_googlecode_to_github/githubissue"
require "vascan_data_googlecode_to_github/cli/application"
require 'json'
require 'octokit'

## from https://gist.github.com/NigelThorne/2913760
class Hash
  def invertHashWithDuplicatedValues()
    self.each_with_object({}) do |(key,value),out| 
      out[value] ||= []
      out[value] << key
    end
  end
end

module VascanDataGooglecodeToGithub
  
  class Migrator
    
    # label definitions
    GIT_HUB_REPO = "Canadensys/vascan-data"
    INCLUDE_LABELS = ['Vascan']
    EXCLUDE_LABELS = ['Section-BackEnd']

    #GoogleCode -> GitHub isssue label mapping 
    #" "Duplicate"=>15, 
    LABEL_MAPPING = {VernacularEN:"vernacularEN", VernacularFR:"vernacularFR", WontFix:"wontfix", Invalid:"invalid"}
    
    GC_ISSUE_TEMPLATE_TEXT = "(This is the template to report a data issue for Vascan. If you want to report another issue, please change the template above.)"
    
    #GoogleCode -> GitHub user mapping
    USER_MAPPING = {"luc.brouillet@umontreal.ca" => "brouille", "manions@natureserve.ca"=>"manions", "marilynanions"=>"manions","frederic.coursol"=>"FredCoursol", "christiangendreau" => "cgendreau"}
    REVERSED_USER_MAPPING = USER_MAPPING.invertHashWithDuplicatedValues
    
    APP_STATE_FILE = "ExportCurrentState.json"
    
    def initialize()
      @issueStatuses = {}
    end
    
    def dryrun(accessToken, googleCodeJSONExportFile)
      #GitHub client
      @client = Octokit::Client.new(:access_token => accessToken)
      user = @client.user
      
      puts "Using GitHub user #{user.login}"
      puts "GoogleCode user(s) #{REVERSED_USER_MAPPING[user.login]}"
      readAppState()
      transferIssues(REVERSED_USER_MAPPING[user.login], googleCodeJSONExportFile, true)
    end
    
    # Inspect the GoogleCode json document according to the shouldInclude? function.
    def inspect(googleCodeJSONExportFile)
      authorHash = Hash.new(0)
      statusesHash = Hash.new(0)
      statesHash = Hash.new(0)
      file = File.read(googleCodeJSONExportFile)
      data_hash = JSON.parse(file, :symbolize_names => true)
      data_hash[:projects][0][:issues][:items].each do |issue|
        if shouldInclude?(issue[:labels])
          authorHash[issue[:author][:name]] += 1;
          statusesHash[issue[:status]]+= 1;
          statesHash[issue[:state]]+= 1;
        end
      end
      puts "#{authorHash.length} distinct authors:#{authorHash.inspect}"
      puts "#{statusesHash.length} distinct statuses:#{statusesHash.inspect}"
      puts "#{statesHash.length} distinct states:#{statesHash.inspect}"
    end
    
    # author as array including aliases
    def transferIssues(author, googleCodeJSONExportFile, dryrun)
      file = File.read(googleCodeJSONExportFile)
      data_hash = JSON.parse(file, :symbolize_names => true)
      data_hash[:projects][0][:issues][:items].each do |issue|
        # ensure we are the author of the issue
        if author && author.include?(issue[:author][:name])
          if shouldInclude?(issue[:labels])
            ghIssue = convertToGitHubIssue(issue)
            submitIssueToGitHub(ghIssue, dryrun)
            handleComments(ghIssue, dryrun)
          end
        end
      end
    end
    
    # Check if we should include the issue in the migration based on its labels
    # if one label is in EXCLUDE_LABELS, this method immediately returns false
    #
    # @param labels [Array] of the GoogleCode labels of the issue
    # @return [Boolean] should the issue with those labels be included
    #
    def shouldInclude? (labels)
      if !(labels & EXCLUDE_LABELS).empty?
        return false
      end
      return !(labels & INCLUDE_LABELS).empty?
    end
    
    # Converts a GoogleCode issue hash into a GitHubIssue object
    #
    # @param gcIssue [Hash] the issue on GoogleCode.
    # @return [GitHubIssue] instance representing the GoogleCode issue formatted for GitHub
    #
    def convertToGitHubIssue (gcIssue)
      ghIssue = GitHubIssue.new
      ghIssue.google_code_id = gcIssue[:id]
      ghIssue.title = gcIssue[:title]
      ghIssue.labels = gcIssue[:labels].collect { |label| LABEL_MAPPING[label.to_sym] }
      #try to map GoogleCode Status to a GitHub label
      ghIssue.labels.push(LABEL_MAPPING[gcIssue[:status].to_sym])
      ghIssue.labels.compact!
      ghIssue.user = USER_MAPPING[gcIssue[:author][:name]]
      
      #identify merged issue
      if gcIssue.has_key?(:mergedInto)
        ghIssue.merged_into = gcIssue[:mergedInto][:issueId]
      end
      
      #the body is the first comment on GoogleCode
      firstComment = gcIssue[:comments][:items][0]
      
      originalDate =  Date.parse(firstComment[:published]).iso8601
      # remove template explanation text 
      issueBody = firstComment[:content].gsub(GC_ISSUE_TEMPLATE_TEXT, "")
      # Always add one line to clearly identify the issue was created on GoogleCode platform
      ghIssue.body = "[Originally posted on GoogleCode (id #{gcIssue[:id]}) on #{originalDate}]\n\n" + issueBody
      
      comments = Array.new 

      # this first comment was already handled
      comments_source = gcIssue[:comments][:items].drop(1)
      comments_source.each_with_index do |comment, index|
        comments.push({author:comment[:author][:name], comment:comment[:content], date:comment[:published], gc_id:comment[:id]})
      end
      ghIssue.comments = comments;

      ghIssue
    end

    # Send the issue to GitHub using octokit
    #
    # @param git_hub_issue [GitHubIssue] the GitHub issue object to submit
    # @param dryrun [Boolean]
    #
    def submitIssueToGitHub(git_hub_issue, dryrun)
      googleCodeId = git_hub_issue.google_code_id
      current_issue_status = @issueStatuses[googleCodeId.to_s.to_sym]
      
      @issueStatuses[googleCodeId.to_s.to_sym] ||= IssueStatus.new({google_code_id:googleCodeId, comments:Array.new })
      current_issue_status = @issueStatuses[googleCodeId.to_s.to_sym]
      
      #Ensure the issue was not already sent
      if !current_issue_status.git_hub_id 
        if dryrun
          puts "DRYRUN: Add issue: #{git_hub_issue} "
        else
          #send the issue to GitHub
          resource = @client.create_issue(GIT_HUB_REPO, git_hub_issue.title, git_hub_issue.body, {labels:git_hub_issue.labels.join(",")})
          sleep 1
          current_issue_status.git_hub_id = resource["number"]
          writeAppState()
        end
      end
    end
    
    # Try to handle comments of an issue
    # The challenge is to keep the ordering of the issue while retaining the issue author
    # @param git_hub_issue [GitHubIssue] the GitHub issue object to submit
    # @param dryrun [Boolean]
    def handleComments(git_hub_issue, dryrun)
      googleCodeId = git_hub_issue.google_code_id
      current_issue_status = @issueStatuses[googleCodeId.to_s.to_sym]
      #get the current comment list for this issue
      gh_issue_comments = @client.issue_comments(GIT_HUB_REPO, current_issue_status.git_hub_id.to_s)
      
      gh_issue_comment_count = gh_issue_comments.size
      gc_comment_count = git_hub_issue.comments.count
      google_code_user = REVERSED_USER_MAPPING[@client.user.login]
      same_author = true
      
      while (gh_issue_comment_count != gc_comment_count) && same_author do
        next_idx = gh_issue_comment_count
        next_comment = git_hub_issue.comments[next_idx]
        #we skip empty comment (used in GoogleCode when a status/state was changed) 
        #also skip comments were already sent
        if next_comment[:comment].empty? || current_issue_status.comments.any? {|h| h[:gc_id] == next_comment[:gc_id]}
          gh_issue_comment_count += 1
          next
        end
        
        #check if WE are the author of the next comment to send
        if google_code_user.include?(next_comment[:author])
          original_date = Date.parse(next_comment[:date])
          original_date_text = original_date.iso8601 + " " + DateTime.parse(next_comment[:date]).strftime("%H:%M")
          comment_text = "[Originally posted on GoogleCode on #{original_date_text}]\n\n" + next_comment[:comment]
          
          if dryrun
            puts "DRYRUN: Add comment: #{comment_text} "
          else
            resource = @client.add_comment(GIT_HUB_REPO, current_issue_status.git_hub_id.to_s, comment_text)
            sleep 1
            current_issue_status.comments.push({gc_id:next_comment[:gc_id], gh_id:resource["id"]})
            writeAppState()
          end
          gh_issue_comment_count += 1
        else
          same_author = false
        end
      end
    end
    
    def readAppState()
      if File.exist?(APP_STATE_FILE)
        file = File.read(APP_STATE_FILE)
        json = JSON.parse(file, :symbolize_names => true)
        @issueStatuses =  Hash[json.map {|k,v| [k, IssueStatus.new(v)]}]
      end
    end
    
    def writeAppState()
      File.open(APP_STATE_FILE,"w") do |f|
        f.write(@issueStatuses.to_json(:include => :issueStatus))
      end
    end
    
    private :transferIssues, :shouldInclude?, :convertToGitHubIssue, :readAppState, :writeAppState, :submitIssueToGitHub
  end
end
