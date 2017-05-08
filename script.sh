#!/usr/bin/env bash

# Let's test for AWS-CLI
command -v aws >/dev/null 2>&1 || { echo "I need aws-cli but it's not installed.  Aborting." >&2; exit 1; }
read -p "AWS profile (default): " -e profile
export AWS_PROFILE=${profile:-default}
aws sts get-caller-identity --query 'Arn' --output text >/dev/null 2>&1 || { echo "Invalid AWS profile. Aborting." >&2; exit 1; }

# Python Version
function run_python(){
python - << EOF
print 'Python Version'

import subprocess
import json
import os

aws_profile = os.environ["AWS_PROFILE"]

def get_keys(user):
  keys = subprocess.check_output(['aws', 'iam', 'list-access-keys', '--user-name', user, '--query', 'AccessKeyMetadata[*][AccessKeyId]', '--profile', aws_profile, '--output', 'text'])
  return keys.splitlines()

users = subprocess.check_output(['aws', 'iam', 'list-users', '--query', 'Users[*].[UserName]', '--profile', aws_profile, '--output', 'text'])

keys = {}
for user in users.splitlines():
  keys[user] = get_keys(user)

print json.dumps(keys, sort_keys=True)
EOF
}

# Ruby Version
function run_ruby() {
export PARALLEL=${1:-false}
ruby - << EOF
  require 'json'
  require 'parallel' if ENV['PARALLEL'] == 'true'

  parallel = ENV['PARALLEL'] == 'true'
  puts parallel ? 'Ruby Parallel Version (using 8 processes)' : 'Ruby Version'

  def get_keys(user)
    keys = %x[aws iam list-access-keys --user-name #{user} --query 'AccessKeyMetadata[*][AccessKeyId]' --profile #{ENV['AWS_PROFILE']} --output text]
    keys.split(/\n/)
  end

  users = %x[aws iam list-users --query 'Users[*].[UserName]' --profile #{ENV['AWS_PROFILE']} --output text]
  users = users.split(/\n/)

  if parallel
    keys = Parallel.map(users, in_processes: 8) do |user|
      [user, get_keys(user)]
    end

    puts Hash[ keys.map{ |a| [a.first,a.last] } ].to_json
  else
    keys = {}
    users.each do |user|
      keys[user] = get_keys(user)
    end

    puts keys.sort.to_json
  end

EOF
}

function check_parallel_gem(){
if ! gem spec parallel > /dev/null 2>&1; then
  echo "Gem parallel is not installed!. Aborting."
  break
fi
}

PS3='Please enter your choice: '
options=("Python" "Ruby" "Both" "parallel" "Quit")
select opt in "${options[@]}"
do
    case $opt in
        "Python")
            run_python
            break
            ;;
        "Ruby")
            run_ruby
            break
            ;;
        "Both")
            run_python
            run_ruby
            break
            ;;
        "parallel")
            check_parallel_gem
            run_ruby true
            break
            ;;
        "Quit")
            echo "bye!"
            break
            ;;
        *) echo invalid option;;
    esac
done
