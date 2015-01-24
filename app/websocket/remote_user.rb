module WS
  class RemoteUser
    include UserBehavior

    attr_reader :id
    attr_reader :node

    def initialize(id)
      @id = id.to_s
      fail WS::User::NotFound.new(id) if @id.empty?
      @node = App.config.redis.get(@id).to_s
      fail WS::User::NotFound.new(id) if @node.empty?
    end

    def send_client(from, action, data)
      return if node.to_s.empty?

      App.logger.info ['REMOTE', self.id, from.id, action]

      data = Oj.dump({ from: from.id, action: action.to_s, data: data }, mode: :compat)
      App.config.redis.publish node, data
    end

  end
end