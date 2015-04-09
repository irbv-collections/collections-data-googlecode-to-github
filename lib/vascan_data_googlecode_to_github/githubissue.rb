module VascanDataGooglecodeToGithub
  #class holding GitHub issue related data
  class GitHubIssue
    attr_accessor :google_code_id, :title, :labels, :user, :body, :merged_into, :comments, :state
  end
  
   #class holding GitHub export status of the issues
  class IssueStatus
    attr_accessor :google_code_id, :git_hub_id, :google_code_merged_into, :comments, :non_blank_gc_comment_count,:gc_state, :gh_state
    
    def initialize ( params={} )
      @google_code_id = params[:google_code_id]
      @git_hub_id = params[:git_hub_id]
      @google_code_merged_into = params[:google_code_merged_into]
      @comments = params[:comments]
      @non_blank_gc_comment_count = params[:non_blank_gc_comment_count]
      @gc_state = params[:gc_state]
      @gh_state = params[:gh_state]
    end
      
    def to_json(*a)
      {
        'google_code_id'=> @google_code_id, 'git_hub_id' => @git_hub_id, 'google_code_merged_into' => @google_code_merged_into, 'comments' => @comments,
        'non_blank_gc_comment_count' => @non_blank_gc_comment_count, 'gc_state' => @gc_state, 'gh_state' => @gh_state
      }.to_json(*a)
    end
  end
end