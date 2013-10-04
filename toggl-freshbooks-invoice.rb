#!/usr/bin/env ruby-1.9.3-p125@toggl-invoice

require 'rest_client'
require "base64"
require 'yaml'
require 'json'
require 'time'
require "rexml/document"


def main
  $config = YAML.load_file(File.join(File.dirname(__FILE__), 'config', 'config.yml'))
  $clients = YAML.load_file(File.join(File.dirname(__FILE__), 'config', 'clients.yml')) # @TODO Refactor this without globals

  unless ARGV.length == 3
    puts 'Usage: toggl-freshbooks-invoice.rb <START_DATE> <END_DATE> "<CLIENT_NAME>"'
    puts '  e.g. toggl-freshbooks-invoice.rb 2013-09-01 2013-09-30 "John Smith"'
    exit(false)
  end
  start_date = ARGV[0]
  end_date = ARGV[1]
  client_name = ARGV[2]

  toggl_response = getTogglSummary(start_date, end_date, client_name)
  toggl_summary = JSON.parse(toggl_response.to_str)
  invoice_data = generateInvoiceData(toggl_summary, start_date, end_date, client_name)
  invoice_request = formatInvoiceRequest(invoice_data)
  freshbooks_response = createInvoice(invoice_request)

  puts freshbooks_response.to_str
  if freshbooks_response.code == 200
    puts
    puts 'A draft of your invoice has been created.'
    puts 'Log in to your FreshBooks account to review and send it.'
	puts getFreshbooksUrl
  end
end

# see https://github.com/toggl/toggl_api_docs/blob/master/reports/summary.md
# and https://github.com/toggl/toggl_api_docs/blob/master/reports.md
def getTogglSummary(date_since, date_until, client_name = nil)
  params = {
    'user_agent' => $config['company']['email'],
    'workspace_id' => $config['toggl']['workspace'],
    'since' => date_since,
    'until' => date_until
  }
  params['client_ids'] = getTogglClientId(client_name) unless client_name.nil?

  response = RestClient::Request.new(
    :method => :get,
    :url => 'https://toggl.com/reports/api/v2/summary',
    :headers => {
      :accept => :json,
      :content_type => :json,
      :authorization => 'Basic ' + Base64.urlsafe_encode64($config['toggl']['api_token'] + ':api_token'),
      :params => params
    }
  ).execute

  if response.code != 200
    puts response.to_str
    raise 'Error retrieving Toggl summary'
  end
  return response
end

# see https://github.com/toggl/toggl_api_docs/blob/master/chapters/workspaces.md#get-workspace-clients
def getTogglClientId(client_name)
  response = RestClient::Request.new(
    :method => :get,
    :url => 'https://www.toggl.com/api/v8/workspaces/' + $config['toggl']['workspace'] + '/clients',
    :headers => { 
      :accept => :json,
      :content_type => :json,
      :authorization => 'Basic ' + Base64.urlsafe_encode64($config['toggl']['api_token'] + ':api_token')
    }
  ).execute

  if response.code != 200
    puts response.to_str
    raise 'Error retrieving Toggl clients'
  end

  JSON.parse(response.to_str).each do |client|
    if client['name'] == client_name
      return client['id']
    end
  end
  raise 'Error retrieving Toggl client id for ' + client_name
end

def generateInvoiceData(toggl_summary, start_date, end_date, client_name)
  formatted_date_range = formatDateRange(start_date, end_date)
  total_hours = millisecondsToHours(toggl_summary['total_grand'])
  notes = <<HERE
Invoice for work: #{formatted_date_range}
Total hours: #{total_hours}

Thank you
HERE
  
  return {
    'client_id' => getFreshbooksClientId(client_name),
    'status' => 'draft',
    'notes' => notes,
    'lines' => generateInvoiceLines(toggl_summary, getClientRate(client_name))
  }
end

def generateInvoiceLines(toggl_summary, rate)
  lines = []
  toggl_summary['data'].each do |project|
    project_title = project['title']['project']
    project['items'].each do |item|
      lines << {
        'name' => project_title,
        'description' => item['title']['time_entry'],
        'unit_cost' => rate,
        'quantity' => millisecondsToHours(item['time']),
        'type' => 'Time'
      }
    end
  end
  return lines
end

# see http://developers.freshbooks.com/docs/invoices/#invoice.create
# and http://developers.freshbooks.com/
def formatInvoiceRequest(invoice_data)
  lines = formatInvoiceLines(invoice_data['lines'])

  return <<HERE
<?xml version="1.0" encoding="utf-8"?>
<request method="invoice.create">
  <invoice>
    #{formatXmlElement(invoice_data, 'client_id')}
    #{formatXmlElement(invoice_data, 'status')}
    #{formatXmlElement(invoice_data, 'notes')}
    <lines>
#{lines}
    </lines>
  </invoice>
</request>
HERE
end

def formatInvoiceLines(lines)
  result = ''
  lines.each do |line|
    result << formatInvoiceLine(line)
  end
  return result
end

def formatInvoiceLine(line)
  return <<HERE
      <line>
        #{formatXmlElement(line, 'name')}
        #{formatXmlElement(line, 'description')}
        #{formatXmlElement(line, 'unit_cost')}
        #{formatXmlElement(line, 'quantity')}
        #{formatXmlElement(line, 'type')}
      </line>
HERE
end

def formatXmlElement(array, key)
  return "<#{key}>#{array[key]}</#{key}>"
end

def createInvoice(invoice_request)
  return requestFreshbooksAPI(invoice_request)
end

def requestFreshbooksAPI(payload)
  return RestClient::Request.new(
    :method => :post,
    :url => getFreshbooksUrl('/api/2.1/xml-in'),
    :user => $config['freshbooks']['api_token'],
    :password => 'X',  # Freshbooks API states this can be any string, they use X in examples, I will too
    :headers => { 
      :accept => :xml,
      :content_type => :xml 
    },
    :payload => payload
  ).execute
end

def getFreshbooksUrl(path = '/')
  return 'https://' + $config['freshbooks']['account'] + '.freshbooks.com' + path
end

def getClientRate(client_name)
  unless $clients && $clients[client_name] && $clients[client_name]['rate']
    raise 'Error accessing rate for ' + client_name
  end
  return $clients[client_name]['rate']
end

def getFreshbooksClientId(client_name)
  unless $clients && $clients[client_name] && $clients[client_name]['freshbooks_client_id']
    raise 'Error accessing freshbooks_client_id for ' + client_name
  end
  return $clients[client_name]['freshbooks_client_id']
end

def millisecondsToHours(t)
  # Round up to the nearest hundredth of an hour
  # We could go to whole hours, tenths, or even thousandths, simply by moving zeroes, but hundredths works for me
  (t.to_f/36000).ceil.to_f/100
end

# format a date range (e.g. September 1 - 15, 2013)
def formatDateRange(start_date_str, end_date_str)
  start_date = Date.parse(start_date_str)
  end_date = Date.parse(end_date_str)
  if start_date.year != end_date.year
    return start_date.strftime('%B %e, %Y') + ' - ' + end_date.strftime('%B %e, %Y')
  elsif start_date.month != end_date.month
    return start_date.strftime('%B %e') + ' - ' + end_date.strftime('%B %e, %Y')
  elsif start_date.day != end_date.day
    return start_date.strftime('%B %e') + ' - ' + end_date.strftime('%e, %Y')
  else
    return start_date.strftime('%B %e, %Y')
  end
end




main
