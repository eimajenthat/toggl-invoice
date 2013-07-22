#!/usr/bin/env ruby-1.9.3-p125@toggl-invoice

require 'rest_client'
require "base64"
require 'yaml'
require 'json'
require 'time'



def main
  $config = YAML.load_file(File.join(File.dirname(__FILE__),'config','config.yml')) # I know, global vars, eww...
  $clients = YAML.load_file(File.join(File.dirname(__FILE__),'config','clients.yml')) # @TODO Refactor this without globals

  toggl_url = 'https://toggl.com/reports/api/v2/summary'

  # In cron, we're going to run this at midnight, and get times, not from the day that just ended,
  # but the prior one, allowing 24 hrs for modifications
  # We can also pass a specific date on the command line.
  date = ARGV.empty? ? (Date.today - 2).to_s : ARGV[0] 

  response = RestClient::Request.new(
    :method => :get,
    :url => toggl_url,
    :headers => { 
      :accept => :json,
      :content_type => :json, 
      :authorization => 'Basic '+Base64.urlsafe_encode64($config['toggl']['api_token']+':api_token'),
      :params => {
        'since' => date,
        'until' => date,
        'user_agent' => $config['company']['email'],
        'workspace_id' => $config['toggl']['workspace'],
        'api_token' => $config['toggl']['api_token']
      }
    },
  ).execute

  exit unless response.code == 200 # This is a cron job, fail silently and don't write bad data

  JSON.parse(response.to_str)['data'].each do |p| 
    
    project = getFreshbooksId(p['title'])

    if project
      p['items'].each do |i|
        enterTime(
          project,
          pickTaskNumber(i['title']['time_entry']),
          millisecondsToHours(i['time']),
          i['title']['time_entry'],
          date
        )
      end
    end
  end
end

def enterTime(project, task, hours, note, date)
  url = 'https://'+$config['freshbooks']['account']+'.freshbooks.com/api/2.1/xml-in'
  xml_request = <<HERE
<?xml version="1.0" encoding="utf-8"?>
<request method="time_entry.create">
  <time_entry>
    <project_id>#{project}</project_id>
    <task_id>#{task}</task_id> 
    <hours>#{hours}</hours>
    <notes>#{note}</notes>
    <date>#{date}</date>
  </time_entry>
</request>
HERE

  response = RestClient::Request.new(
    :method => :post,
    :url => url,
    :user => $config['freshbooks']['api_token'],
    :password => 'X',  # Freshbooks API states this can be any string, they use X in examples, I will too
    :headers => { 
      :accept => :xml,
      :content_type => :xml 
    },
    :payload => xml_request
  ).execute

end

def getFreshbooksId(project)
  p = project['project']
  c = project['client']
  if $clients && $clients[c] && $clients[c]['projects'] && $clients[c]['projects'][p] && $clients[c]['projects'][p]['freshbooks_id']
    return $clients[c]['projects'][p]['freshbooks_id']
  else
    return false
  end
end

def millisecondsToHours(t)
  # Round up to the nearest hundredth of an hour
  # We could go to whole hours, tenths, or even thousandths, simply by moving zeroes, but hundredths works for me
  (t.to_f/36000).ceil.to_f/100
end

def pickTaskNumber(desc)
  # This code should probably be abstracted or generalized for other peoples' needs, but it works for me.
  # Note that 'met ' requires the space to match, to avoid false positives.
  task = 1 # General
  if desc.downcase.start_with?('meet','call','met ', 'chat')
    task = 2 # Meeting
  elsif desc.downcase.start_with?('research','read', 'review')
    task = 3 # Research
  end
  return task      
end




main
