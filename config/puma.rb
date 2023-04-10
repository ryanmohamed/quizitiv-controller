require 'rack/config'
require 'rack/handler/puma'
require_relative './app'

workers Integer(2)
threads_count = Integer(5)
threads threads_count, threads_count

preload_app!

rackup      DefaultRackup
port        ENV['PORT']     || 3000
environment ENV['RACK_ENV'] || 'development'

on_worker_boot do
  ActiveRecord::Base.establish_connection if defined?(ActiveRecord)
end
