#!/usr/bin/env ruby
Encoding.default_external = 'UTF-8'

require 'telegram/bot'

require_relative 'private_keys'
require_relative 'bot'

DEBUG = (ARGV[0] == '--debug')
token = (DEBUG) ? (TELEGRAM_TOKEN_DEBUG) : (TELEGRAM_TOKEN)

admin = User.new uid: 1
conf = {cycle: true, admin: (admin.tid.nil?) ? (nil) : (admin)}

bot = Bot.new conf

while conf[:cycle] do
	conf[:cycle] = false if DEBUG
	puts "New cycle..."
	begin
		Telegram::Bot::Client.run(token) do |tbot|
			tbot.listen do |message|
				begin
					bot.receive tbot.api, message
				rescue Exception => e 
					puts e.message
					puts e.backtrace.inspect
					tbot.api.send_message(chat_id: conf[:admin].tid, text: e)
					tbot.api.send_message(chat_id: conf[:admin].tid, text: e.backtrace.inspect)
				end
			end
		end
	rescue Exception => e
		puts e
	end
end
