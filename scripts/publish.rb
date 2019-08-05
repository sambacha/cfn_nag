# frozen_string_literal: true

require 'fileutils'
require 'cfn-nag/util/git.rb'
require 'docker'

GEM_CREDENTIALS = '~/.gem/credentials'
REPO_DIR = '.'

private

def validate_env
  ENV.fetch('rubygems_api_key')
  ENV.fetch('docker_user')
  ENV.fetch('docker_password')
rescue StandardError => exception
  raise 'Environment variable not set'
end

def build_gem(gem_version)
  File.open(GEM_CREDENTIALS, 'w', 0o600) { |file| file.write ":rubygems_api_key: #{rubygems_api_key}" }
  system('gem build cfn-nag.gemspec')
  system("gem push cfn-nag-#{gem_version}.gem")
end

def publish_docker_image(gem_version)
  image = Docker::Image.build_from_dir('.')
  image.tag('repo' => "#{ENV['docker_org']}/cfn_nag",
            'tag' => gem_version)
  image.tag('repo' => "#{ENV['docker_org']}/cfn_nag",
            'tag' => 'latest')
  image.push
  # image.push(nil, tag: gem_version)
  # image.push(nil, tag: 'latest')
end

def update_changelog
  system('node node_modules/auto-changelog/lib/index.js --template changelog-template.hbs')
  git_update_changelog
rescue StandardError => exception
  abort("Update changelog error:  #{exception}")
end

validate_env
repo_info = git_repo_current_info(REPO_DIR)
git_tag_repo(REPO_DIR, repo_info['next_version']) unless repo_info['tagged_commit']
gem_version = (repo_info['tagged_commit'] ? repo_info['version'] : repo_info['next_version'])
build_gem(gem_version)
publish_docker_image(gem_version)
update_changelog
