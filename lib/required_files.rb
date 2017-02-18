require "required_files/version"
require 'octokit'

module RequiredFiles
  class Client
    def initialize(github_token)
      @github_token = github_token
    end

    def github_client
      Octokit::Client.new(access_token: @github_token, auto_paginate: true)
    end

    def copy_required_files
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
      repo = github_client.repo("#{user_or_org}/required-files")
      get_file_list(repo, true)
    end

    def copy_files_for_account(user_or_org)
      required_files = find_required_files(user_or_org)
      return if required_files.empty?
      repos = find_repos(user_or_org)
      repos.each do |repo|
        copy_files_to_repo(repo.full_name, required_files)
      end
    end

    def copy_files_to_repo(repo, required_files)
      file_list = get_file_list(repo)
      required_files.each do |required_file|
        next if file_exists?(required_file, file_list)
        create_file(repo, required_file)
      end
    end

    def get_file_list(repo, include_contents = false)
      files = github_client.tree(repo.full_name, repo.default_branch, recursive: true)[:tree].select{|f| f.type == 'blob' }
      if include_contents
        files.map! do |file|
          github_client.contents(repo.full_name, path: file.path)
        end
      else
        files
      end
    end

    def file_exists?(required_file, file_list)
      file_list.map(&:path).include?(required_file.path)
    end

    def create_file(repo, required_file)
      github_client.create_contents(repo,
                                    required_file.path,
                                    "Adding #{required_file.path}",
                                    Base64.decode64(required_file.content))
    end
  end
end
