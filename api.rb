require 'sinatra'
require 'json'
require 'google/cloud/firestore' 
require 'dotenv/load'

# read json from file path, turn into hash
credentials_json = File.read ENV['GOOGLE_APPLICATION_CREDENTIALS']
credentials_hash = JSON.parse credentials_json

# create environment variables 
ENV['FIRESTORE_PROJECT_ID'] = credentials_hash['project_id']

# establish firestore client with credentials 
firestore = Google::Cloud::Firestore.new(
    project_id: ENV['FIRESTORE_PROJECT_ID'],
    credentials: ENV['GOOGLE_APPLICATION_CREDENTIALS']
)
if not defined? firestore 
    raise StandardError.new "Could not connect to Firestore..."
else
    print "Sucessfully connected to Quizitiv Firestore...\n"
end


# middleware to check if authorization is an actual user from the database
before do 
    content_type :json
    unless request.env['HTTP_AUTHORIZATION']
        halt 401, { message: "You are missing an Authorization header..." }.to_json
    end

    token = request.env['HTTP_AUTHORIZATION'].split(' ').last

    # fetch users from firestore
    firestore.doc("Users/token")

end

# submit answers 
post '/submit_answers' do 
    # Rack::Request and Rack:: Response
    # params = hash request parameters
    # on http request, hash of info is passed as env
    # convert json into hash

    if not defined? firestore
        halt 503, "Server unable to access database..."
    end

    body = JSON.parse(request.body.read)
    token = request.env['HTTP_AUTHORIZATION'].split(' ').last
    quiz_id = body["quiz_id"] # string
    answers = body["answers"] # array 

    content_type :json
    return { message: "Request succesful", data: "Some data"}.to_json
end

# get '/firestore' do 

#     user_col =firestore.col('Users')
#     users = user_col.get
#     users.each { |user| print user }

# end