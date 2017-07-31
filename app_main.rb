require 'sinatra'
require 'line/bot'
require 'json'
require 'uri'
require 'net/http'

get '/' do
  "Hello world Web test"
end

def client
  @client ||= Line::Bot::Client.new { |config|
    config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
    config.channel_token  = ENV["LINE_CHANNEL_TOKEN"]
  }
end

post '/callback' do
  body = request.body.read

  signature = request.env['HTTP_X_LINE_SIGNATURE']
  unless client.validate_signature(body, signature)
    error 400 do
      'Bad Request'
    end
  end

  # ぐるなびapi
  # query_key = 'keyid=0981d433e05e9b622e56f239060ca60d&format=json&freeword='
  # area = ''
  # food = ''
  # query = query_key + area + food + '&hit_per_page=5'

  # uri_string = URI::Generic.build(scheme: 'https', host: 'api.gnavi.co.jp', path: '/RestSearchAPI/20150630/', query: query).to_s
  # uri        = URI.parse(uri_string)
  # json       = Net::HTTP.get(uri)
  # results    = JSON.parse(json)
  #
  # columns = []
  #
  # results['rest'].each_with_index do |result, index|
  #   hash                      = {}
  #   hash['thumbnailImageUrl'] = result['image_url']['shop_image1']
  #   hash['title']             = result['name'][0, 40]
  #   hash['text']              = 'description'
  #   hash['actions']           = [
  #     {
  #       type:  "postback",
  #       label: "Buy",
  #       data:  "action=buy&itemid=111"
  #     },
  #     {
  #       type:  "postback",
  #       label: "Add to cart",
  #       data:  "action=add&itemid=111"
  #     },
  #     {
  #       type:  "uri",
  #       label: "お店の情報を見る",
  #       uri:   "#{result['url_mobile']}"
  #     }
  #   ]
  #   columns[index]            = hash
  # end

  events = client.parse_events_from(body)
  events.each { |event|
    case event
    when Line::Bot::Event::Message
      case event.type
      when Line::Bot::Event::MessageType::Text
        query     = ''
        query_key = 'keyid=0981d433e05e9b622e56f239060ca60d&format=json&freeword='

        if event.message['text'] =~ /(\s|　)/
          area  = $`
          food  = $'
          query = query_key + area + "\s" + food + '&hit_per_page=5'

          uri_string = URI::Generic.build(scheme: 'https', host: 'api.gnavi.co.jp', path: '/RestSearchAPI/20150630/', query: query).to_s
          uri        = URI.parse(uri_string)
          json       = Net::HTTP.get(uri)
          results    = JSON.parse(json)

          columns = []

          results['rest'].each_with_index do |result, index|
            hash                      = {}
            hash['thumbnailImageUrl'] = result['image_url']['shop_image1']
            hash['title']             = result['name'][0, 40]
            hash['text']              = 'description'
            hash['actions']           = [
              {
                type:  "postback",
                label: "Buy",
                data:  "action=buy&itemid=111"
              },
              {
                type:  "postback",
                label: "Add to cart",
                data:  "action=add&itemid=111"
              },
              {
                type:  "uri",
                label: "お店の情報を見る",
                uri:   "#{result['url_mobile']}"
              }
            ]
            columns[index]            = hash
          end
        end

        message  = {
          type: 'text',
          text: event.message['text']
        }
        question = {
          type:     "template",
          altText:  "this is a confirm template",
          template: {
            type:    "confirm",
            text:    "Are you sure?",
            actions: [
                       {
                         type:  "message",
                         label: "Yes",
                         text:  "yes"
                       },
                       {
                         type:  "message",
                         label: "No",
                         text:  "no"
                       }
                     ]
          }
        }
        carousel = {
          type:     "template",
          altText:  "this is a carousel template",
          template: {
            type:    "carousel",
            columns: columns
          }
        }

        if event.message['text'] == '確認'
          client.reply_message(event['replyToken'], message)
        else
          client.reply_message(event['replyToken'], carousel)
        end
      when Line::Bot::Event::MessageType::Image, Line::Bot::Event::MessageType::Video
        response = client.get_message_content(event.message['id'])
        tf       = Tempfile.open("content")
        tf.write(response.body)
      end
    when Line::Bot::Event::Postback
      message = {
        type: 'text',
        text: 'OK'
      }
      client.reply_message(event['replyToken'], message)
    end
  }

  "OK"
end
