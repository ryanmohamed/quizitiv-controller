# Quizitiv Controller
###  Controller for Quizitiv's MVC architecture 
[Deploy](https://quizitiv-controller.herokuapp.com/submit_answers)
### Built with Sinatra.
---
## Run `bundle install` to download dependencies. 
---
## Find the client-side repo [here](https://github.com/ryanmohamed/quizitiv)
---
### Dependency rationale
  1. `gem 'sinatra'`
    Sinatra, fast to get rolling, easy to scale, complex tasks in Rails not required in Quizitiv web app architecture.
  
  2. `gem 'google-cloud-firestore'`
    Google Cloud Firestore for accessing Firestore database for CRUD operations. 
    
  3. `gem 'google-cloud-error_reporting'`
    Error handling for JWT tokens, expiration, issuer, audience, etc.
  
  4. `gem 'jwt'`
    Decoding of JWT token based on hash algorithm used by Firebase (SHA256).
    
  5. `gem 'httparty'`
    Simplified GET request to retrieve Google public keys.
    
  6. `gem 'dotenv'`
    Sensitive data, read environment variables pushed to Heroku. 
--- 
### Dev Log 🚧
**05-08-2023 9:08PM**
  - [x] Capitalization and whitespace issue with quiz submission. 
  - [x] Server should return answer key after scoring has been performed. 
  - [ ] See test case ```answers = ['a','johnathan      math', 'a'] answer_key = ['a','johnathanmath', 'a']```
---
