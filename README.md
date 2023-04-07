# Quizitiv-Controller
## Controller for MVC architecture. Built with Sinatra.
---
## Run `bundle install` to download dependencies. 
---
Find the client-side repo [here](https://github.com/ryanmohamed/quizitiv)

### Dependency rationale
  1. `gem 'sinatra'`
    Sinatra, fast to get rolling, easy to scale, complex tasks in Rails not required in Quizitiv web app architecture.
  
  2. `google-cloud-firestore`
    Google Cloud Firestore for accessing Firestore database for CRUD operations. 
  3. `firebase_admin`
    Verification of tokens sent by client on controller actions. Token initially sent by Firebase as it handles authentication. 
