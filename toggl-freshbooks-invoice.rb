#!/usr/bin/env ruby-1.9.3-p125@toggl-invoice

require 'json'
require 'yaml'
require_relative 'lib/datetime'
require_relative 'lib/freshbooks'
require_relative 'lib/toggl'

def main
  config = YAML.load_file(File.join(File.dirname(__FILE__), 'config', 'config.yml'))
  clients = YAML.load_file(File.join(File.dirname(__FILE__), 'config', 'clients.yml'))

  unless ARGV.length == 3
    puts 'Usage: toggl-freshbooks-invoice.rb <START_DATE> <END_DATE> "<CLIENT_NAME>"'
    puts '  e.g. toggl-freshbooks-invoice.rb 2013-09-01 2013-09-30 "John Smith"'
    exit(false)
  end
  start_date = ARGV[0]
  end_date = ARGV[1]
  client_name = ARGV[2]

  toggl_response = getTogglSummary(config, start_date, end_date, client_name)
  toggl_summary = JSON.parse(toggl_response.to_str)
  invoice_data = generateInvoiceData(clients, toggl_summary, start_date, end_date, client_name)
  invoice_request = formatInvoiceRequest(invoice_data)
  freshbooks_response = createInvoice(config, invoice_request)

  puts freshbooks_response.to_str
  if freshbooks_response.code == 200
    puts
    puts 'A draft of your invoice has been created.'
    puts 'Log in to your FreshBooks account to review and send it.'
    puts getFreshbooksUrl(config)
  end
end

def generateInvoiceData(clients, toggl_summary, start_date, end_date, client_name)
  formatted_date_range = formatDateRange(start_date, end_date)
  total_hours = millisecondsToHours(toggl_summary['total_grand'])
  notes = <<HERE
Invoice for work: #{formatted_date_range}
Total hours: #{total_hours}

Thank you
HERE
  
  return {
    'client_id' => getFreshbooksClientId(clients, client_name),
    'status' => 'draft',
    'notes' => notes,
    'lines' => generateInvoiceLines(toggl_summary, getClientRate(clients, client_name))
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
  return "<#{key}>#{array[key].to_s.encode(:xml => :text)}</#{key}>"
end

def createInvoice(config, invoice_request)
  return requestFreshbooksAPI(invoice_request, config)
end

def getClientRate(clients, client_name)
  unless clients && clients[client_name] && clients[client_name]['rate']
    raise 'Error accessing rate for ' + client_name
  end
  return clients[client_name]['rate']
end

def getFreshbooksClientId(clients, client_name)
  unless clients && clients[client_name] && clients[client_name]['freshbooks_client_id']
    raise 'Error accessing freshbooks_client_id for ' + client_name
  end
  return clients[client_name]['freshbooks_client_id']
end




main
