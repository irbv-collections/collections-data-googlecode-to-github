module VascanDataGooglecodeToGithub
  #class holding GitHub issue related data
  class GitHubIssue
    attr_accessor :google_code_id, :title, :labels, :user, :body, :merged_into, :comments
  end
  
   #class holding GitHub export status of the issues
  class IssueStatus
    attr_accessor :google_code_id, :git_hub_id, :google_code_merged_into, :comments
    
    def initialize ( params={} )
      @google_code_id = params[:google_code_id]
      @git_hub_id = params[:git_hub_id]
      @google_code_merged_into = params[:google_code_merged_into]
      @comments = params[:comments]
    end
      
    def to_json(*a)
      {
        'google_code_id'=> @google_code_id, 'git_hub_id' => @git_hub_id, 'google_code_merged_into' => @google_code_merged_into, 'comments' => @comments
      }.to_json(*a)
    end
  end
end