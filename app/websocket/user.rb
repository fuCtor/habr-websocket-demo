module WS
  class User

    include UserBehavior

    attr_reader :id

    class Error < StandardError; end
    class RoomFull < Error; end
    class NotFound < Error
      attr_reader :id
      def initialize(id); @id = id end
      def to_s; "User '@#{id}' not found" end
    end

    class NotUnique < Error; end

    class  << self
      def cache
        @ws_cache ||= {}
      end

      def get(id)
        fail NotFound.new(id) if id.to_s.empty?
        @ws_cache.fetch(id)
      rescue KeyError
        WS::RemoteUser.new(id)
      end

      def register(ws)
        self.new(ws)
      end

      def unregister(ws)
        url = URI.parse(ws.url)
        id = url.path.split('/').last
        get(id).unregister
      end
    end

    def initialize(ws)
      @ws = ws
      register

      @pingpong = EM.add_periodic_timer(5) do
        @ws.ping('') do
          App.config.redis.expire @id, 15 if App.config.redis
        end
      end
    end

    def unregister
      on_close if respond_to? :on_close

      App.config.active.decrement

      App.config.redis.del @id if App.config.redis
      User.cache.delete(@id)

      @pingpong.cancel
      @pingpong = nil
      @ws = nil
      @id = nil
    end

    def send_client(from, action, data)
      return unless @ws
      data = Oj.dump({ from: from.id, action: action.to_s, data: data }, mode: :compat)
      @ws.send(data)
    end

    private
    def register
      url = URI.parse(@ws.url)
      @id = url.path.split('/').last

      if App.config.redis
        App.config.redis.multi do
          App.config.redis.set @id, App.id
          App.config.redis.expire @id, 15
        end

        App.config.sessions.increment
        App.config.active.increment
      end

      User.cache[@id] = self

      App.logger.info [:open, @ws.url, @ws.version, @ws.protocol]

      on_register if respond_to? :on_close

      self
    end
  end
end