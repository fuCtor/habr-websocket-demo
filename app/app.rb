require 'ostruct'

module App
  class << self
    def configuration
      yield(config) if block_given?
      config.sessions = Metriks.counter('total_sessions')
      config.active = Metriks.counter('active_sessions')
    end
    
    def config			
      @config ||= OpenStruct.new( redis: nil, root: nil )
    end	
    
    def id
      @instance_id ||= SecureRandom.hex
    end

    def logger
      @logger ||= Logger.new $stderr
    end

    def register
      config.redis.multi do
        config.redis.set "node_#{App.id}", true
        config.redis.expire "node_#{App.id}", 60*10
      end if config.redis

      EM.next_tick do        
        config.sub = PubSub.connect

        config.sub.subscribe App.id do |type, channel, message|
          case type
            when 'message'
              begin
                json = Oj.load(message, mode: :compat)
                WS::Base.remote_messsage json
              rescue => ex
                App.logger.error "ERROR: #{message.class} #{message} #{ex.to_s}"
              end
            else
              App.logger.debug "(#{type}) #{channel}:: #{message}"
          end
        end

        @pingpong = EM.add_periodic_timer(30) do
          App.config.redis.expire "node_#{App.id}", 60
        end
      end
    rescue
      config.redis = nil
    end
  end
end