#!/usr/bin/env ruby-1.9.3-p125@toggl-invoice

require 'yaml'
require 'json'
require 'time'
require "rexml/document"
require_relative 'lib/freshbooks'
require_relative 'lib/toggl'


def main
  $config = YAML.load_file(File.join(File.dirname(__FILE__),'config','config.yml')) # I know, global vars, eww...
  $clients = YAML.load_file(File.join(File.dirname(__FILE__),'config','clients.yml')) # @TODO Refactor this without globals

  # In cron, we're going to run this at midnight, and get times, not from the day that just ended,
  # but the prior one, allowing 24 hrs for modifications
  # We can also pass a specific date on the command line.
  date = ARGV.empty? ? (Date.today - 2).to_s : ARGV[0] 

  response = getTogglSummary(date, date)

  exit unless response.code == 200 # This is a cron job, fail silently and don't write bad data

  deleteTime(date) # Delete existing entries for that date, to avoid dupes

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
  create_request = <<HERE
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

  response = requestFreshbooksAPI(create_request)

end

def deleteTime(date)
  # Before we write all the new time entries, let's delete the existing ones to avoid dupes
  # http://developers.freshbooks.com/docs/time-entries/#time_entry.delete
  # will have to parse time_entry.list, then delete each ID, I think
  
  list_request = <<HERE
<?xml version="1.0" encoding="utf-8"?>
<request method="time_entry.list">
  <page>1</page>
  <per_page>1000</per_page>
  <date_from>#{date}</date_from>
  <date_to>#{date}</date_to>
</request>
HERE
  response = requestFreshbooksAPI(list_request)
  xml = REXML::Document.new response
  xml.elements.each("response/time_entries/time_entry/time_entry_id") do |element| 
    delete_request = <<HERE
<?xml version="1.0" encoding="utf-8"?>
<request method="time_entry.delete">
  <time_entry_id>#{element.text}</time_entry_id>
</request>
HERE

    response = requestFreshbooksAPI(delete_request)
  end
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
