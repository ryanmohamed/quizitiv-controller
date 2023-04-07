require 'sinatra'
require 'json'
require 'google/cloud/firestore' 
require 'httparty'
require 'jwt'
require 'dotenv/load'

# read json from file path, turn into hash
credentials_json = File.read ENV['GOOGLE_APPLICATION_CREDENTIALS']
credentials_hash = JSON.parse credentials_json

# create environment variables 
ENV['FIRESTORE_PROJECT_ID'] = credentials_hash['project_id']

# we're gonna need to validate firebase tokens sent by clients
# but no official sdk to solve this problem
# thanks to ryuta hamasaki for the original idea and explanation @ https://ryutahamasaki.com/posts/verify-firebase-auth-jwt-with-ruby/
# follows directly from what is stated here... https://firebase.google.com/docs/auth/admin/verify-id-tokens#verify_id_tokens_using_a_third-party_jwt_library
def decode_header (token)
    encoded = token.split('.').first
    return JSON.parse(Base64.decode64(encoded))
end

def check_algo (token)
    jwt_algo = "RS256".freeze # firebase uses an RS256 hash, set a constant variable
    header = decode_header(token)
    algo = header["alg"]
    if algo != jwt_algo
        raise "Invalid token algorithm #{algo}. Expected RS-256."
    end
    return header 
end

def get_public_key(kid)
    public_key_url = "https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com".freeze
    response = HTTParty.get(public_key_url)
    
    unless response.success?
        raise "Failed to fetch JWT public keys from Google."
    end

    public_keys = response.parsed_response

    # todo: cache public keys,

    unless public_keys.include?(kid)
        raise "Invalid token 'kid' header, does not match valid public key."
    end

    return OpenSSL::X509::Certificate.new(public_keys[kid]).public_key
end

def verify_jwt(token)
    firebase_project_id = ENV['FIRESTORE_PROJECT_ID']
    header = decode_header(token)
    check_algo(token)
    public_key = get_public_key(header["kid"])
    options = {
        algorithm: "RS256",
        verify_iat: true,
        verify_aud: true, 
        aud: firebase_project_id,
        verify_iss: true,
        iss: "https://securetoken.google.com/#{firebase_project_id}"
    }
    print JWT.decode(token, public_key, true, options)
end


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
    verify_jwt(token)
    # if token
    #     begin
    #         # use auth class to verify the token and send responses as need
    #         decoded = FirebaseAdmin::Auth.verify_id_token(token)
    #         print(decoded, "\n")
    #     end
    # end

    # # fetch users from firestore
    # firestore.doc("Users/token")

end

# submit answers 
post '/submit_answers' do 
    # Rack::Request and Rack:: Response
    # params = hash request parameters
    # on http request, hash of info is passed as env
    # convert json into hash

    # if not defined? firestore
    #     halt 503, "Server unable to access database..."
    # end

    # body = JSON.parse(request.body.read)
    # token = request.env['HTTP_AUTHORIZATION'].split(' ').last
    # quiz_id = body["quiz_id"] # string
    # answers = body["answers"] # array 

    # content_type :json
    # return { message: "Request succesful", data: "Some data"}.to_json
end

# get '/firestore' do 

#     user_col =firestore.col('Users')
#     users = user_col.get
#     users.each { |user| print user }

# end