class Web < Sinatra::Base

  helpers do
    def client_id
      @client_id ||= SecureRandom.hex
    end

    def ws_url
      "ws://#{request.host }:#{request.port}/ws/#{client_id}"
    end
  end

  get '/' do
    haml :index
  end
end