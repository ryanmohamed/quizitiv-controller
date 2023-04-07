require 'sinatra'
require 'json'
require 'google/cloud/firestore' 
require 'httparty'
require 'jwt'
require 'dotenv/load'

# read json from file path, turn into hash
credentials_json = File.read ENV['GOOGLE_APPLICATION_CREDENTIALS']
credentials_hash = JSON.parse credentials_json

# create environment variables & constants
ENV['FIRESTORE_PROJECT_ID'] = credentials_hash['project_id']
JWT_HASH_ALGO = "RS256".freeze # firebase uses an RS256 hash, set a constant variable

# we're gonna need to validate firebase tokens sent by clients
# but no official sdk to solve this problem
# thanks to ryuta hamasaki for the original idea and explanation @ https://ryutahamasaki.com/posts/verify-firebase-auth-jwt-with-ruby/
# follows directly from what is stated here... https://firebase.google.com/docs/auth/admin/verify-id-tokens#verify_id_tokens_using_a_third-party_jwt_library
# reinterpreted slightly 

def decode_header (token) # => decoded JSON header
    halt 401, { message: 'Could not decode token. Invalid format.' }.to_json unless token.include? '.'
    encoded_header = token.split('.').first
    begin
        return JSON.parse(Base64.decode64(encoded_header))
    rescue 
        halt 401, { message: "Could not decode token. Not Base64 encoded." }.to_json
    end
end

def check_algo (decoded_header) # => halts execution if header is not jwt encoded
    alg = decoded_header["alg"]
    if alg != JWT_HASH_ALGO
        halt 401, { message: "Invalid token algorithm #{alg}. Expected #{JWT_HASH_ALGO}." }.to_json
    end
end

def get_public_key(kid)
    # fetch public key from firebase
    public_key_url = "https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com".freeze
    response = HTTParty.get(public_key_url)
    
    unless response.success?
        halt 503, "Failed to fetch JWT public keys from Google."
    end

    public_keys = response.parsed_response

    # todo: cache public keys

    unless public_keys.include?(kid)
        halt 503, "Invalid token 'kid' header, does not match valid public key."
    end

    return OpenSSL::X509::Certificate.new(public_keys[kid]).public_key
end

def verify_jwt(token, public_key)
    firebase_project_id = ENV['FIRESTORE_PROJECT_ID']
    options = {
        algorithm: "RS256",
        verify_iat: true,
        verify_aud: true, 
        aud: firebase_project_id,
        verify_iss: true,
        iss: "https://securetoken.google.com/#{firebase_project_id}"
    }
    # error handling for decoding the jwt token
    begin
        return JWT.decode(token, public_key, true, options)
    rescue JWT::ExpiredSignature => e
        halt 401, { message: "Token is expired." }.to_json
    rescue JWT::InvalidIssuerError => e
        halt 401, { message: "Token was not issued by firebase project." }.to_json
    rescue JWT::InvalidAudError => e
        halt 401, { message: "Token has invalid audience." }.to_json
    rescue JWT::InvalidAlgorithmError => e
        halt 401, { message: "Token uses incorrect algorithm." }.to_json
    rescue => e
        halt 401, { message: "An error occured decoding token." }.to_json
    end
end

# middleware to check if authorization is an actual user from the database
before do 
    content_type :json
    unless request.env['HTTP_AUTHORIZATION']
        halt 401, { message: "You are missing an Authorization header..." }.to_json
    end
    token = request.env['HTTP_AUTHORIZATION'].split(' ').last
    if token
        begin
            # Verify the ID token's header conforms to Firebase JWT algorithm and key id corresponds to https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com
            decoded_token_header = decode_header(token) # can halt if an error is thrown and return a failed status code
            check_algo(decoded_token_header) # can halt if an error is thrown and return a failed status code
            # Verify signature of JWT token using public key
            verify_jwt token, get_public_key(decoded_token_header["kid"])
        end
    end
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