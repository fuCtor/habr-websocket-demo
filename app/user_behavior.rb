module UserBehavior
  module ClassMethods
    def register_action(action, params = {})
      return App.logger.info ['register_action', "Method #{action} already defined"] if respond_to? action

      block = lambda do |*args |
        if block_given?
          data, from = yield(self, *args)
          send_client from || self, action, data
        else
          send_client self, action, args.first
        end
      end

      define_method action, &block
      define_method "on_#{action}" do |data|
        self.send action, data
      end if params[:passthrough]

    end
  end

  def self.included(base)
    base.instance_exec do
      extend ClassMethods
      register_action :message do |user, from, text|
        [{ to: user.id, text: text }, from]
      end

      register_action :error, passthrough: true
    end
  end

  def on_message(data)
    App.logger.info ['MESSAGE', id, data.to_s]

    to_user_id = data['to']
    to_user = WS::User.get(to_user_id)
    to_user.message self, data['text']

  rescue WS::User::NotFound  => ex
    error({ error: ex.to_s })
  end
end