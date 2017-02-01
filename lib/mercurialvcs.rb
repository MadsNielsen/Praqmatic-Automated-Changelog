#!/usr/bin/env ruby
# encoding: utf-8
require "mercurial-ruby"

module Vcs

  class MercurialVcs
    attr_accessor :repository
    def initialize(settings)
      
      Mercurial.configure do |conf|
        conf.hg_binary_path = "/usr/bin/hg"
      end 
      
      @repository = Mercurial::Repository.open(settings['repo_location'])
    end
  
    #Converting from string to time and striping the hours
    def date_converter(datestring)
      DateTime.strptime(datestring, "%Y-%m-%d").to_time
    end
  
    #Get commit messages by specifying the secured hash algorithm (SHA) of the commits
    def get_commit_messages_by_commit_sha(tailCommitSHA, headCommitSHA=nil)
      raise ArgumentError, 'Tail commit SHA parameter is nil' if tailCommitSHA.nil?
  
      headCommit = @repository.commits.tip
      headCommitSha = headCommit.to_s
  
      if headCommitSHA.nil?
      headCommitSHA = headCommitSha
      end
      shas = []
      @repository.commits.each do |commit|
  
        if commit.hash_id.include? tailCommitSHA
          commitTailCommitSHADate = commit.date.to_s
          @commitTailCommitSHADate = commitTailCommitSHADate
        end
        if commit.hash_id.include? headCommitSHA
          commitHeadCommitSHADate = commit.date.to_s
          @commitHeadCommitSHADate = commitHeadCommitSHADate
        end
      end
      result = get_commits_by_time_with_hours(@commitTailCommitSHADate,@commitHeadCommitSHADate)
      return result
    end
  
    #Get commits by specifying a start and an end tag
    def get_commit_messages_by_tag_name(tailTagName, headTagName=nil)
      raise ArgumentError, 'Tail tag name is nil' if tailTagName.nil?
  
      commit_messages = []
      @repository.commits.each do |commit|
        if commit.tags_names.include? tailTagName
          commitTailTagDate = commit.date.to_s
          @commitTailTagDate = commitTailTagDate
        end
        if commit.tags_names.include? headTagName
          commitHeadTagDate = commit.date.to_s
          @commitHeadTagDate = commitHeadTagDate
        end
      end
      
      result = get_commits_by_time_with_hours(@commitTailTagDate,@commitHeadTagDate)
      return result
    end
  end
  
end