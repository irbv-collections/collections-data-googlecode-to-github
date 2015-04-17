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
    EXCLUDE_LABELS = ['Section-BackEnd','Section-Interface','Section-Support']

    #GoogleCode -> GitHub isssue label mapping 
    LABEL_MAPPING = {VernacularEN:"vernacularEN",:'Vernacular-EN'=>"vernacularEN",VernacularFR:"vernacularFR",:'Vernacular-FR'=>"VernacularFR", WontFix:"wontfix", Invalid:"invalid"}
    
    GC_ISSUE_TEMPLATE_TEXT = "(This is the template to report a data issue for Vascan. If you want to report another issue, please change the template above.)"
    
    #GoogleCode -> GitHub user mapping
    USER_MAPPING = {"luc.brouillet@umontreal.ca" => "brouille", "manions@natureserve.ca"=>"manions", "marilynanions"=>"manions", "frederic.coursol"=>"FredCoursol","genevieve.croisetiere"=>"FredCoursol", 
      "marc.favreau@tpsgc-pwgsc.gc.ca" => "MFavreau", "christiangendreau" => "cgendreau", "davidpshorthouse"=> "dshorthouse", 
      "peter.desmet.cubc"=> "peterdesmet","hall.geoffrey" => "geoffreyhall","sjmeades@sympatico.ca" => "sjmeades", "papooshki"=> "MichaelOldham"}
    REVERSED_USER_MAPPING = USER_MAPPING.invertHashWithDuplicatedValues
    
    APP_STATE_FILE = "ExportCurrentState.json"
    
    def initialize()
      @issueStatuses = {}
    end
    
    def dryrun(accessToken, googleCodeJSONExportFile, write_gc_author=false)
      #GitHub client
      @client = Octokit::Client.new(:access_token => accessToken)
      user = @client.user
      
      puts "-DRY RUN-"
      puts "Using GitHub user #{user.login}"
      puts "GoogleCode user(s) #{REVERSED_USER_MAPPING[user.login]}"
      readAppState()
      transferIssues(user.login, googleCodeJSONExportFile, true, write_gc_author)
    end
    
    def run(accessToken, googleCodeJSONExportFile, write_gc_author=false)
      #GitHub client
      @client = Octokit::Client.new(:access_token => accessToken)
      user = @client.user
      
      puts "Using GitHub user #{user.login}"
      puts "GoogleCode user(s) #{REVERSED_USER_MAPPING[user.login]}"
      readAppState()
      transferIssues(user.login, googleCodeJSONExportFile, false, write_gc_author)
      writeAppState()
    end
    
    # Inspect the GoogleCode json document according to the shouldInclude? function.
    def inspect(googleCodeJSONExportFile)
      authorHash = Hash.new(0)
      statusesHash = Hash.new(0)
      statesHash = Hash.new(0)
      labelsHash = Hash.new(0)
      file = File.read(googleCodeJSONExportFile)
      data_hash = JSON.parse(file, :symbolize_names => true)
      data_hash[:projects][0][:issues][:items].each do |issue|
        if shouldInclude?(issue[:labels])
          authorHash[issue[:author][:name]] += 1;
          statusesHash[issue[:status]]+= 1;
          statesHash[issue[:state]]+= 1;
          issue[:labels].each do |lbl|
            labelsHash[lbl] += 1
          end
          #Display attachments
          #issue[:comments][:items].each do |comment|
          #  if comment[:attachments] && issue[:state] == 'open'
          #   puts "Attachments for GoogleCode issue #{issue[:id]}"
          #  comment[:attachments].each do |attachement|
          #    puts attachement
          #  end
          # end
          #end
        end
      end
      puts "#{authorHash.length} distinct authors:#{authorHash.inspect}"
      puts "#{statusesHash.length} distinct statuses:#{statusesHash.inspect}"
      puts "#{statesHash.length} distinct states:#{statesHash.inspect}"
      puts "#{labelsHash.length} distinct labels:#{labelsHash.inspect}"
    end
    
    # Inspect the "states" JSON document
    def inspect_states()
      readAppState()
      @issueStatuses.each do |key, data|
        if data.gc_state && data.gc_state != data.gh_state
          puts "GoogleCode Issue #{key} should be #{data.gc_state}. GitHub id: #{data.git_hub_id}"
        end
      end
      
    end
    
    # @param github_user [String] GitHub user name of the connected user
    # @param google_code_json_export_file [String] path of the file containing the GoogleCode export JSON document
    # @param dryrun [Boolean] GitHub user name of the connected user
    # @param write_gc_author [Boolean] write the GoogleCode user in the generate comment line, used when transfering issues for a user with no GitHub account
    def transferIssues(github_user, google_code_json_export_file, dryrun, write_gc_author)
      file = File.read(google_code_json_export_file)
      puts "Reading GoogleCode export JSON file ..."
      data_hash = JSON.parse(file, :symbolize_names => true)
      puts "Iterating over GoogleCode issues ..."
      data_hash[:projects][0][:issues][:items].each do |issue|
        if shouldInclude?(issue[:labels])
          ghIssue = convertToGitHubIssue(issue,write_gc_author)
          # ensure we are the author of the issue
          if github_user == ghIssue.user
            submitIssueToGitHub(ghIssue, dryrun)
            handleComments(ghIssue, dryrun, write_gc_author)
            tryCloseIssue(ghIssue, dryrun)
          #if we are NOT the author, check if we commented the issue
          elsif ghIssue.comments.any? {|c| github_user == c[:author]}
            handleComments(ghIssue, dryrun, write_gc_author)
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
    # # @param write_gc_author [Boolean]
    # @return [GitHubIssue] instance representing the GoogleCode issue formatted for GitHub
    #
    def convertToGitHubIssue (gcIssue, write_gc_author)
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
      by_comment = ""
      if write_gc_author === true
        by_comment = " by #{gcIssue[:author][:name].split("@")[0]}"
      end
      
      # Always add one line to clearly identify the issue was created on GoogleCode platform
      ghIssue.body = "[Originally posted on GoogleCode (id #{gcIssue[:id]}) on #{originalDate}#{by_comment}]\n\n" + issueBody
      
      comments = Array.new 

      # this first comment was already handled
      comments_source = gcIssue[:comments][:items].drop(1)
      comments_source.each_with_index do |comment, index|
        #skip deleted comments
        if !comment[:deletedBy]
          comments.push({author:USER_MAPPING[comment[:author][:name]],gc_author:comment[:author][:name], comment:comment[:content], date:comment[:published], gc_id:comment[:id]})
        end
      end
      ghIssue.comments = comments
      ghIssue.state = gcIssue[:state]
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
      current_issue_status.gc_state = git_hub_issue.state
      
      #We do not send merged issue to GitHub
      if git_hub_issue.merged_into
        current_issue_status.google_code_merged_into = git_hub_issue.merged_into
        return
      end
      
      #Ensure the issue was not already sent
      if !current_issue_status.git_hub_id 
        if dryrun
          puts "DRYRUN: Add issue: #{git_hub_issue.inspect} "
        else
          #send the issue to GitHub
          resource = @client.create_issue(GIT_HUB_REPO, git_hub_issue.title, git_hub_issue.body, {labels:git_hub_issue.labels.join(",")})
          sleep 4
          current_issue_status.git_hub_id = resource["number"]
          current_issue_status.gh_state = "open"
          writeAppState()
        end
      end
    end
    
    # Try to handle comments of an issue
    # The challenge is to keep the ordering of the issue while retaining the issue author
    # @param git_hub_issue [GitHubIssue] the GitHub issue object to submit
    # @param dryrun [Boolean]
    # @param write_gc_author [Boolean]
    def handleComments(git_hub_issue, dryrun, write_gc_author)
      googleCodeId = git_hub_issue.google_code_id
      @issueStatuses[googleCodeId.to_s.to_sym] ||= IssueStatus.new({google_code_id:googleCodeId, comments:Array.new })
      current_issue_status = @issueStatuses[googleCodeId.to_s.to_sym]
      current_issue_status.non_blank_gc_comment_count = git_hub_issue.comments.count { |comment| !comment[:comment].empty? }
      
      # If the issue (parent object) does NOT exist on GitHub OR if the issue is closed on GitHub, returns
      if !current_issue_status.git_hub_id || current_issue_status.gh_state == "closed"
        return
      end
        
      github_user = @client.user.login
      #get the current comment list for this issue
      gh_issue_comments = @client.issue_comments(GIT_HUB_REPO, current_issue_status.git_hub_id.to_s)
      gh_issue_comment_count = gh_issue_comments.size
      
      #if count matches, assume it's up-to-date and return
      if current_issue_status.non_blank_gc_comment_count == gh_issue_comment_count
        return
      end
      
      gc_comment_count = git_hub_issue.comments.count
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
        if github_user == next_comment[:author]
          original_date = Date.parse(next_comment[:date])
          original_date_text = original_date.iso8601 + " " + DateTime.parse(next_comment[:date]).strftime("%H:%M")
          by_comment = ""
          if write_gc_author === true
            by_comment = " by #{next_comment[:gc_author].split("@")[0]}"
          end
          comment_text = "[Originally posted on GoogleCode on #{original_date_text}Z#{by_comment}]\n\n" + next_comment[:comment]
          
          if dryrun
            puts "DRYRUN: Add comment: #{comment_text} "
          else
            resource = @client.add_comment(GIT_HUB_REPO, current_issue_status.git_hub_id.to_s, comment_text)
            sleep 4
            current_issue_status.comments.push({gc_id:next_comment[:gc_id], gh_id:resource["id"]})
            writeAppState()
          end
          gh_issue_comment_count += 1
        else
          same_author = false
        end
      end
    end
    
    # To close an Issue it needs to have the 'closed' status on Vascan and all wanted(non blank, non deleted) comments transfered on GitHub.
    # This function assumes the logged user is allowed to Close the provided issue
    def tryCloseIssue(git_hub_issue, dryrun)
      google_code_id = git_hub_issue.google_code_id
      current_issue_status = @issueStatuses[google_code_id.to_s.to_sym]
      
      # check if it was at the state "closed" on GoogleCode
      if current_issue_status && current_issue_status.git_hub_id && current_issue_status.gc_state == "closed"
        # check 
        if current_issue_status.gh_state != current_issue_status.gc_state && current_issue_status.non_blank_gc_comment_count == current_issue_status.comments.length
          if dryrun
            puts "DRYRUN: close GitHub issue #{current_issue_status.git_hub_id} (GoogleCode:#{current_issue_status.google_code_id})"
          else
            @client.close_issue(GIT_HUB_REPO, current_issue_status.git_hub_id)
            current_issue_status.gh_state = "closed"
            writeAppState()
          end
        end
      end
    end
    
    def readAppState()
      if File.exist?(APP_STATE_FILE)
        puts "Reading status file ..."
        file = File.read(APP_STATE_FILE)
        json = JSON.parse(file, :symbolize_names => true)
        @issueStatuses =  Hash[json.map {|k,v| [k, IssueStatus.new(v)]}]
      end
    end
    
    def writeAppState()
      File.open(APP_STATE_FILE,"w") do |f|
        f.write(JSON.pretty_generate(@issueStatuses))
      end
    end
    
    private :transferIssues, :shouldInclude?, :convertToGitHubIssue, :readAppState, :writeAppState, :submitIssueToGitHub, :tryCloseIssue
  end
end
