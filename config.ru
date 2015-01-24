require './init'

run Rack::Cascade.new [WS::Base, Web]