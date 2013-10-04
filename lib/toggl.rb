require 'base64'
require 'json'
require 'rest_client'

# assumes configuration has been loaded to $config
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
      :authorization => getTogglAuthHeader,
      :params => params
    }
  ).execute

  if response.code != 200
    puts response.to_str
    raise 'Error retrieving Toggl summary'
  end
  return response
end

# assumes configuration has been loaded to $config
# see https://github.com/toggl/toggl_api_docs/blob/master/chapters/workspaces.md#get-workspace-clients
def getTogglClientId(client_name)
  response = RestClient::Request.new(
    :method => :get,
    :url => 'https://www.toggl.com/api/v8/workspaces/' + $config['toggl']['workspace'] + '/clients',
    :headers => { 
      :accept => :json,
      :content_type => :json,
      :authorization => getTogglAuthHeader
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

# assumes configuration has been loaded to $config
def getTogglAuthHeader
  return 'Basic ' + Base64.urlsafe_encode64($config['toggl']['api_token'] + ':api_token')
end
