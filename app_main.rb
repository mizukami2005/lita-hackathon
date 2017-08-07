require 'sinatra'
require 'line/bot'
require 'json'
require 'uri'
require 'net/http'

post '/' do
  # "Hello world Web test"
  # 'OK'
  params
end

post '/hoge' do
  'Yes'
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

  events = client.parse_events_from(body)
  events.each { |event|
    case event
    when Line::Bot::Event::Message
      case event.type
      when Line::Bot::Event::MessageType::Text
        key = ENV["API_KEY"]


        if event.message['text'] =~ /(\s|　)/
          area  = $`
          food  = $'
          query = "keyid=#{key}&format=json&freeword=#{area}\s#{food}"

          uri_string = URI::Generic.build(scheme: 'https', host: 'api.gnavi.co.jp', path: '/RestSearchAPI/20150630/', query: query).to_s
          uri        = URI.parse(uri_string)
          results    = ''
          begin
            response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
              http.get(uri.request_uri)
            end
            case response
            when Net::HTTPSuccess
              json    = response.body
              results = JSON.parse(json)
            end
          rescue => e
          end

          columns = []

          if results['rest'].nil?
            error_message = {
              type: 'text',
              text: '見つからなかったよ!'
            }
            client.reply_message(event['replyToken'], error_message)
          else
            results['rest'].shuffle.first(5).each_with_index do |result, index|
              hash = {}
              if result['image_url']['shop_image1'].empty?
                hash['thumbnailImageUrl'] = 'https://raw.githubusercontent.com/mizukami2005/lita-hackathon/master/no_image.png'
              else
                hash['thumbnailImageUrl'] = result['image_url']['shop_image1']
              end
              hash['title']   = result['name'][0, 40]
              hash['text']    = result['category'][0, 60]
              hash['actions'] = [
                {
                  type:  "postback",
                  label: "投票",
                  data:  "name=#{result['name'][0, 40]}"
                },
                {
                  type:  "postback",
                  label: "地図を見る",
                  data:  "#{result['address']},#{result['latitude']},#{result['longitude']}"
                },
                {
                  type:  "uri",
                  label: "お店の情報を見る",
                  uri:   "#{result['url_mobile']}"
                }
              ]
              columns[index]  = hash
            end
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
      if event["postback"]["data"].include?('name')
        name    = event["postback"]["data"].split('=')
        message = {
          type: 'text',
          text: name[1]
        }
      else
        address = event["postback"]["data"].split(',')
        message = {
          type:      'location',
          title:     '場所',
          address:   address[0],
          latitude:  address[1],
          longitude: address[2]
        }
      end
      client.reply_message(event['replyToken'], message)
    end
  }

  "OK"
end
