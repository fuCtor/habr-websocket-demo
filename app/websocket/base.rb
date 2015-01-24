module WS
  class Base
    NEXT_RACK = [404, {}, []].freeze

    def self.call(*args)
      instance.call(*args)
    end

    def self.instance
      @instance ||= self.new
    end

    def self.remote_messsage(json)
      user = User.get json['from']
      instance.send :process, user, json if user
    rescue => ex
      user.error( { error: ex.to_s } )
    end

    def initialize
      @ws_cache = {}
    end

    def call(env)
      return NEXT_RACK unless Faye::WebSocket.websocket?(env)

      ws = Faye::WebSocket.new(env, ['xmpp'], ping: 5)
      user = User.register(ws)

      ws.onmessage = lambda do |event|
        json = Oj.load(event.data, mode: :compat)
        process(user, json )
      end

      ws.onclose = lambda do |event|
        App.logger.info [:close, event.code, event.reason]
        user.unregister
        user = nil
      end

      ws.rack_response
    rescue WS::User::NotUnique => ex
      ws.send Oj.dump({ action: :error, data: { error: 'not unique session' } })
      ws.close
      ws.rack_response
    end

    private

    def process(user, json)
      action = json['action'].to_s
      data = json['data']

      return App.logger.info([:message, 'Empty action']) if action.empty?
      return App.logger.info([:message, "Unknown action #{json['action']}"]) unless user.respond_to? "on_#{action}"

      user.send "on_#{action}", data
    rescue => ex
      user.error({ error: ex.to_s })
      puts ex.to_s
      puts ex.backtrace
    end
  end
end