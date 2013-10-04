require 'rest_client'

# assumes configuration has been loaded to $config
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

# assumes configuration has been loaded to $config
def getFreshbooksUrl(path = '/')
  return 'https://' + $config['freshbooks']['account'] + '.freshbooks.com' + path
end
