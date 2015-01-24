require 'bundler'
Bundler.require

require 'securerandom'

ENV['RACK_ENV'] ||= 'development'

if ENV['RACK_ENV'] == 'development'
  module Rack
    class Lint
      def call(env = nil)
        @app.call(env)
      end
    end
  end
end

Faye::WebSocket.load_adapter('thin')

APP_ROOT = File.expand_path('..', __FILE__)

require File.join(APP_ROOT, 'app', 'app.rb')

App.configuration do |config|
	config.root = APP_ROOT
	config.redis = Redis.new
end

Dir[File.join(APP_ROOT, 'app', '*.rb')].each { |file| require file }
Dir[File.join(APP_ROOT, 'app', 'websocket', '*.rb')].each { |file| require file }

WS::Base.instance
App.register