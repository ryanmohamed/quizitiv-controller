require 'sinatra'
require 'json'
require 'google/cloud/firestore' 
require "google/cloud/error_reporting"
require 'dotenv/load'
require_relative 'verify-jwt'
#
# read json from file path, turn into hash
credentials_json = File.read ENV['GOOGLE_APPLICATION_CREDENTIALS']
credentials_hash = JSON.parse credentials_json

# create environment variables & constants
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
        halt 401, { message: "You are missing an Authorization header." }.to_json
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
    if not defined? firestore
        halt 503, "Server unable to access database..."
    end
end


get '/' do 
    content_type :json
    return { message: "Hello from Controller!" }.to_json
end

# submit answers 
post '/submit_answers' do 
    # middleware verifies the Firebase connection & JWT token in Authorization header
    body = JSON.parse(request.body.read)
    uid = body["uid"]
    quiz_id = body["quiz_id"] # string
    answers = body["answers"] # array 

    # now that we have the firebase connection & JWT token, we can fetch the answers for this quiz
    quiz_snapshot = firestore.doc("Quizzes/#{quiz_id}").get
    halt 404, { message: "Quiz not found." }.to_json unless quiz_snapshot.exists?
    quiz_data = quiz_snapshot.data

    # fetch answers from firebase and count correct answers
    answer_key = Array.new
    quiz_data[:questions].each { |question| answer_key.push (question[:answer].downcase()) }
    score = (answer_key & answers).length # take intersection of two arrays

    # update this quiz data
    user_ref = nil
    begin
        user_ref = firestore.doc("Users/#{uid}")
    rescue Google::Cloud::NotFoundError
        halt 404, { message: "User not found." }.to_json
    end

    s = "Scoring performed."

    # update user's score information, only if they have none defined already, can only submit first attempt
    user_snapshot = user_ref.get
    if user_snapshot.exists?
        user_scores = user_snapshot.data[:scores]
        user_xp = user_snapshot.data[:xp]
            
        # update db only if first attempt, we still need to return a score even on repeated submissions so no halting
        if user_scores.none? {|score_record| score_record[:id] == quiz_id }
            new_score = { id: quiz_id, score: score, rating: 0 }
            # we'll only update the xp if the quiz wasn't created by this user
            new_xp = quiz_data[:uid] == uid ? user_xp : user_xp + (score*10)
            begin
                user_ref.set( {scores: user_scores + [new_score], xp: new_xp} , merge: true )
            rescue => e
                halt 500, { message: "An error occured while updating user score." }.to_json
            end
            s = "Score submitted. Succesfully wrote to database."
        end
    end

    content_type :json
    return { message: s, score: "#{score}"}.to_json
end

post '/submit_rating' do # max 2 reads 2 writes

    # middleware verifies the Firebase connection & JWT token in Authorization header
    body = JSON.parse(request.body.read)
    uid = body["uid"]
    quiz_id = body["quiz_id"] # string
    rating = body["rating"] # integer 

    # fetch the user first, practice strong exception handling
    user_ref = firestore.doc("Users/#{uid}")
    user_snapshot = user_ref.get
    halt 404, { message: "User not found." }.to_json unless user_snapshot.exists?

    # update user's individual score rating, for quick reloads in view
    user_scores = user_snapshot.data[:scores]
    halt 400, { message: "User has never taken quiz before or has rated it already."}.to_json unless user_scores.any? {|score_record| score_record[:id] == quiz_id and score_record[:rating].to_i == 0 }

    idx = user_scores.find_index {|score_record| score_record[:id] == quiz_id }
    new_score = { id: quiz_id, score: user_scores[idx][:score], rating: rating }
    user_scores[idx] = new_score
    begin
        user_ref.set( {scores: user_scores}, merge: true )
    rescue => e
        halt 500, { message: "Error: #{e.message}" }.to_json
    end

    # fetch quiz and update it's tracking data  
    quiz_ref = firestore.doc("Quizzes/#{quiz_id}")
    quiz_snapshot = quiz_ref.get
    halt 404, { message: "Quiz not found." }.to_json unless quiz_snapshot.exists?
   
    prev_rating = quiz_snapshot.data[:rating].to_f
    prev_attempts = quiz_snapshot.data[:attempts].to_i
    new_rating = (prev_rating + rating.to_f)/2.0

    begin
        quiz_ref.set( { attempts: prev_attempts + 1, rating: new_rating }, merge: true )
    rescue => e
        halt 500, { message: "Error: #{e.message}" }.to_json
    end

    content_type :json
    return { message: "Rating submitted!", new_rating: "#{new_rating}", attempts: "#{prev_attempts+1}"}.to_json

end