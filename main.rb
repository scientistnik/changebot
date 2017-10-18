#!/usr/bin/env ruby
Encoding.default_external = 'UTF-8'

require 'telegram/bot'

require_relative 'user'
require_relative 'announce'
require_relative 'assets'
require_relative 'private_keys'

DEBUG = (ARGV[0] == '--debug')
token = (DEBUG) ? (TELEGRAM_TOKEN_DEBUG) : (TELEGRAM_TOKEN)

kbutton = Telegram::Bot::Types::InlineKeyboardButton
markup = Telegram::Bot::Types::ReplyKeyboardMarkup


cycle = true
while cycle do
cycle = false if DEBUG
puts "New cycle..."
begin
Telegram::Bot::Client.run(token) do |bot|
  bot.listen do |message|
begin
		if User.in_blacklist? message.from
			bot.api.send_message(chat_id: message.chat.id, text: "Вы в черном списке. Если Вы попали туда случайно обратитесь к админу @scientistnik")
			next
		end

		user = User.new message.from

		case message
		when Telegram::Bot::Types::Message
			case message.text
			when '/start'
				question = "Что Вас интересует?"
				answers =
					Telegram::Bot::Types::ReplyKeyboardMarkup
					.new(keyboard: [['🇷🇺 bitRUB', '🇺🇸 bitUSD'],['🇲🇵 bitEUR','🏵 bitBTC'],['✉️ Мои объявления','💵 Кошелек']])
				bot.api.send_message(chat_id: user.tid, text: question, reply_markup: answers)
			when '/stop'
				if user.name == 'scientistnik'
					bot.api.send_message(chat_id: user.tid, text: 'Ухожу в сон. Всем пока!')
					cycle = false
				else
					kb = Telegram::Bot::Types::ReplyKeyboardRemove.new(remove_keyboard: true)
					bot.api.send_message(chat_id: message.chat.id, text: 'Sorry to see you go :(', reply_markup: kb)
				end
			when '✉️ Мои объявления'
				kb = []
				user.announces.each do |ann|
					kb << kbutton.new(text: "Вы отдаете #{ann.give}, получаете #{ann.get}", callback_data: "ann-edit_#{ann.id}")
				end
				if kb.empty?
					#kb << kbutton.new(text: 'Создать свое объявление', callback_data: "new#{k}")
					#markup = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)
					#bot.api.send_message(chat_id: message.chat.id, text: 'У Вас нет объявлений', reply_markup: markup)
					bot.api.send_message(chat_id: message.chat.id, text: 'У Вас нет объявлений')
				else
					markup = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)
					bot.api.send_message(chat_id: message.chat.id, text: 'Вот Ваши объявления:', reply_markup: markup)
				end
			when /^.?.? bit/
				asset = Asset.get message.text[/bit.*/]
				kb = []
				arr_col = [ kbutton.new(text: asset.name, callback_data: "sell_#{asset.name}")]
				Asset.all_without(asset).each do |as|
					next if as.name[/^bit/]
					size = Announce.count_pair asset.id, as.id
					arr_col << kbutton.new(text: "#{as.name} (#{size})", callback_data: "pair_#{as.name}_#{asset.name}")
					if arr_col.size == 2
						kb << arr_col
						arr_col = []
					end
				end
				kb << arr_col if arr_col.size > 0
				markup = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)
				bot.api.send_message(chat_id: message.chat.id, text: "‼️Что вы хотите отдать?‼️\n\nЕсли в данном списке не хватает нужного пункта, пожалуйста напишите мне. Прям тут напишите!", reply_markup: markup)
			when /^.?.? Кошелек/
				bot.api.send_message(chat_id: message.chat.id, text: "Данная опция проходит стадию тестирования....Если хотите принять участие в тестировании просто напишитемне...прям тут...")
			else
				if !user.status.nil? && user.status[/^new_/]
					give, get = user.status.split('_')[1..-1].map {|e| Asset.get e}
					Announce.create user.id, give.id, get.id, message.text
					user.status = nil
					bot.api.send_message(chat_id: message.chat.id, text: 'Сообщение сохранено. Спасибо!')
				elsif user.name == 'scientistnik'
					if user.status.nil? || user.status.empty?
						kb = []
						kb << kbutton.new(text: 'Показать пользователей', callback_data: "admin_show_users")
						markup = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)
						bot.api.send_message(chat_id: message.chat.id, text: 'Доброго времени суток, хозяин! Кому-то хотите написать?', reply_markup: markup)
					elsif user.status[/^send_/]
						uname = User.new username: user.status[5..-1]
						bot.api.send_message(chat_id: uname.tid, text: message.text)
						user.status = nil
					end
				else
					question = "Что Вас интересует?"
					answers =
						Telegram::Bot::Types::ReplyKeyboardMarkup
						.new(keyboard: [['🇷🇺 bitRUB', '🇺🇸 bitUSD'],['🇲🇵 bitEUR','🏵 bitBTC'],['✉️ Мои объявления']])
					bot.api.send_message(chat_id: user.tid, text: question, reply_markup: answers)
					bot.api.send_message(chat_id: User.new(username: 'scientistnik').tid, text: "Пользователь #{user} написал боту: #{message.text}")
				end
			end

		when Telegram::Bot::Types::CallbackQuery
			call = message.data
			case call
			when 'admin_show_users'
				kb = []
				arr_col = []
				User.all.each do |u|
					arr_col << kbutton.new(text: "@#{u.name}", callback_data: "admin_send_#{u.name}")
					if arr_col.size == 4
						kb << arr_col
						arr_col = []
					end
				end
				kb << arr_col if arr_col.size > 0
				markup = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)
				bot.api.send_message(chat_id: message.from.id, text: "Кому написать?", reply_markup: markup)
			when 'admin_cancel_send'
				user.status = nil
			when /^admin_send_/
				uname = User.new username: call[11..-1]
				user.status = "send_#{uname.name}"
				kb = []
				kb << kbutton.new(text: "Отменить", callback_data: 'admin_cancel_send')
				markup = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)
				bot.api.send_message(chat_id: message.from.id, text: "Что пользователю #{uname.name} написать?", reply_markup: markup)
			when /^sell_/
				asset = Asset.get call.split("_")[-1]
				kb = []
				arr_col = []
				Asset.all_without(asset).each do |get|
					next if get.name[/^bit/]
					size = Announce.count_pair get.id, asset.id
					arr_col << kbutton.new(text: "#{get.name} (#{size})", callback_data: "pair_#{asset.name}_#{get.name}")
					if arr_col.size == 2
						kb << arr_col
						arr_col = []
					end
				end
				kb << arr_col if arr_col.size < 2
				markup = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)
				bot.api.send_message(chat_id: message.from.id, text: "Вы отдаете #{asset.name}. ‼️Что Вы хотите получить?‼️\n\nЕсли в данном списке не хватает пункта, пожалуйста обратитесь к администратору бота @scientistnik", reply_markup: markup)
			when /^ann-new_/
				give, get = call.split('_')[1..-1].map {|e| Asset.get e}
				user.status = "new_#{give.name}_#{get.name}"
				bot.api.send_message(chat_id: message.from.id, text: "Напишите объявление:\n\nПожалуйста укажите в объявлении следующие пункты:\n1. Курс обмена. Из объявления должно быть понятно, сколько Вы готовы отдать, а сколько получить.\n2. Количественное ограничение. Если Вы готовы к обмену имея ограничения на минимальный и/или максимальный объем, укажите это!\n3. Укажите время в течении которого Вы оперативно сможите осуществить обмен. Не забудьте указать часовой пояс!")
			when /^ann-show_/
				ann = Announce.get_id call.split('_')[-1]
				if !ann.id.nil?
					kb = []
					kb << kbutton.new(text: 'Начать обмен', callback_data: "change_#{ann.give}_#{ann.get}_#{ann.user}")
					markup = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)
					bot.api.send_message(chat_id: message.from.id, text: "Объявление @#{ann.user}, он отдает #{ann.give}, получает #{ann.get}:\n\n#{ann.message}", reply_markup: markup)
				else
					bot.api.send_message(chat_id: message.from.id, text: "Объявление @#{name} по обмену #{para} не найдено!")
				end
			when /^ann-edit_/
				ann = Announce.get_id call.split("_")[-1]
				kb = [[kbutton.new(text: 'Редактировать', callback_data: "ann-new_#{ann.give}_#{ann.get}"),kbutton.new(text: 'Удалить', callback_data: "ann-del_#{ann.id}")]]
				markup = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)
				bot.api.send_message(chat_id: message.from.id, text: ann.message, reply_markup: markup)
			when /^ann-del_/
				Announce.del call.split('_')[-1]
				bot.api.send_message(chat_id: message.from.id, text: 'Объявление удалено')
			when /^change_/
				give_nm, get_nm, user_nm = call.split('_')[1..-1]
				give = Asset.get give_nm
				get = Asset.get get_nm
				chuser = User.new username: user_nm
				bot.api.send_message(chat_id: chuser.tid, text: "Пользователь @#{user.name} хочет произвести обмен #{get} на #{give}! Свяжитесь с ним для обмена!")

				kb = []
				#kb << kbutton.new(text: "Оцените #{chuser.name}", callback_data: "karma@#{chuser.name}")
				#markup = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)
				bot.api.send_message(chat_id: message.from.id, text: "Пользователь @#{chuser.name} извещен! Свяжитесь с ним для обмена!") #, reply_markup: markup)
			when /^pair_/
				give, get = call.split('_')[1..-1].map {|e| Asset.get e}
				arr = Announce.get_all giveas: get.id, getas: give.id
				kb = []
				arr_col = []
				arr.each do |ann|
					arr_col << kbutton.new(text: "@#{ann.user}", callback_data: "ann-show_#{ann.id}")
					if arr_col.size == 2
						kb << arr_col
						arr_col = []
					end
				end
				kb << arr_col if arr_col.size > 0
				kb << kbutton.new(text: '📊 Безопасный обмен', callback_data: "bot-new_#{give}_#{get}")
				kb << kbutton.new(text: 'Создать свое объявление', callback_data: "ann-new_#{give}_#{get}")
				if arr.empty?
					markup = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)
					bot.api.send_message(chat_id: message.from.id, text: "Нет подходящих вариантов. \n\nВы можете осуществить сделку через бота или добавить собственное объявление.", reply_markup: markup)
				else
					markup = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)
					bot.api.send_message(chat_id: message.from.id, text: 'Доступные', reply_markup: markup)
				end
			when /^bot-new_/
				give, get = call.split('_')[1..-1].map {|e| Asset.get e}
				bot.api.send_message(chat_id: User.new(username: 'scientistnik').tid, text: "Пользователь @#{user} хочет поменять #{give} на #{get}")
				bot.api.send_message(chat_id: user.tid, text: "📊 Безопасный обмен\n\n‼️Это обмен между часными лицами с частичным или полным участием бота.‼️\n\n Обмен происходит в три этапа:\n\n1. Владелец bitAsset пересылает на аккаунт бота желаемый объем bitAsset для обмена и указывает номер карточки. \n2. Покупатель bitAsset переводит средства на карточку.\n3. После подтверждения перевода средств, бот переводит bitAsset в заданный аккаунт.\n\nКомиссию бот берет у желающего приобрести bitAsset. \n\nНа данный момент, комиссия составляет 10 рублей.")
			else
				p "Неверный запрос)))"
			end
		end
	rescue Exception => e 
		puts e.message
		puts e.backtrace.inspect
		admin = User.new username: 'scientistnik'
		bot.api.send_message(chat_id: admin.tid, text: e)
		bot.api.send_message(chat_id: admin.tid, text: e.backtrace.inspect)
	end
  end
end
rescue Exception => e
	puts e
end
end
