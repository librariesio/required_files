require "required_files/version"

module RequiredFiles
  class Client
    def initialize(github_token)
      @github_token = github_token
    end

    def github_client
      Octokit::Client.new(access_token: github_token)
    end

    def run
      copy_files_for_account(github_client.user.login)
      find_orgs.each do |org|
        copy_files_for_account(org.login)
      end
    end

    def find_orgs
      github_client.organizations
    end

    def find_repos(user_or_org)
      repos = github_client.repos(user_or_org)
      repos.reject(&:fork?)
    end

    def find_required_files(user_or_org)
      repo_name = "#{user_or_org}/required-files"
      github_client.contents(repo_name)
    end

    def copy_files_for_account(user_or_org)
      required_files = find_required_files(user_or_org)
      repos = find_repos(user_or_org)
      repos.each do |repo|
        copy_files_to_repo(repo, required_files)
      end
    end

    def copy_files_to_repo(repo, required_files)
      file_list = github_client.contents(repo)
      required_files.each do |required_file|
        next if file_exists?(required_file, file_list)
        create_file(repo, required_file)
      end
    end

    def file_exists?(required_file, file_list)
      file_list.include?(required_file)
    end

    def create_file(repo, required_file)
      Octokit.create_contents(repo,
                              file_name,
                              commit_message,
                              file_contents,
                              branch: branch_name)
    end
  end
end
