module VascanDataGooglecodeToGithub
  #class holding GitHub issue related data
  class GitHubIssue
    attr_accessor :title, :labels, :user, :body
  end
end