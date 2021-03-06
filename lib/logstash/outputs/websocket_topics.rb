# encoding: utf-8
require "json"
require "logstash/namespace"
require "logstash/outputs/base"

# This output runs a websocket server and publishes any 
# messages to all connected websocket clients.
#
# You can connect to it with ws://<host\>:<port\>/
#
# If no clients are connected, any messages received are ignored.
class LogStash::Outputs::WebSocket < LogStash::Outputs::Base
  config_name "websocket_topics"

  # The address to serve websocket data from
  config :host, :validate => :string, :default => "0.0.0.0"

  # The port to serve websocket data from
  config :port, :validate => :number, :default => 3232

  public
  def register
    require "ftw"
    require "logstash/outputs/websocket_topics/app"
    @channels = {}
    @server = Thread.new(@channels) do |channels|
      begin
        Rack::Handler::FTW.run(LogStash::Outputs::WebSocket::App.new(channels, @logger),
                               :Host => @host, :Port => @port)
      rescue => e
        @logger.error("websocket server failed", :exception => e)
        sleep 1
        retry
      end
    end
  end # def register

  public
  def receive(event)
    topic = event['topic']
    json = JSON.generate(event)
    if @channels.has_key?(topic) 
      @channels[topic].publish(json)
    else
      require "logstash/outputs/websocket_topics/pubsub"
      pubsub = LogStash::Outputs::WebSocket::Pubsub.new
      pubsub.logger = @logger
      @channels[topic] = pubsub
      pubsub.publish(json)
    end # if
  end # def receive

end # class LogStash::Outputs::Websocket
