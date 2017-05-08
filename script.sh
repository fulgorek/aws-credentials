#!/usr/bin/env bash

# Let's test for AWS-CLI
command -v aws >/dev/null 2>&1 || { echo "I need aws-cli but it's not installed.  Aborting." >&2; exit 1; }
read -p "AWS profile (default): " -e profile
export AWS_PROFILE=${profile:-default}
aws sts get-caller-identity --query 'Arn' --output text >/dev/null 2>&1 || { echo "Invalid AWS profile. Aborting." >&2; exit 1; }

# Python Version
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


# Ruby Version
ruby - << EOF
  require 'json'
  puts 'Ruby Version'

  def get_keys(user)
    keys = %x[aws iam list-access-keys --user-name #{user} --query 'AccessKeyMetadata[*][AccessKeyId]' --profile #{ENV['AWS_PROFILE']} --output text]
    keys.split(/\n/)
  end

  users = %x[aws iam list-users --query 'Users[*].[UserName]' --profile #{ENV['AWS_PROFILE']} --output text]

  keys = {}
  users.split(/\n/).each do |user|
    keys[user] = get_keys(user)
  end

  puts keys.sort.to_json
EOF
