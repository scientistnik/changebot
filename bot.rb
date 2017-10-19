require_relative 'user'
require_relative 'announce'
require_relative 'assets'

class Bot

	IKM = Telegram::Bot::Types::InlineKeyboardMarkup
	IKB = Telegram::Bot::Types::InlineKeyboardButton
	RKM = Telegram::Bot::Types::ReplyKeyboardMarkup
	RKR = Telegram::Bot::Types::ReplyKeyboardRemove

	attr_accessor :conf, :user, :api

	def initialize _conf
		@conf = _conf
	end

	def first_RKM
		RKM.new(keyboard: [['🇷🇺 bitRUB', '🇺🇸 bitUSD'],['🇲🇵 bitEUR','🏵 bitBTC'],['✉️ Мои объявления','💵 Кошелек']])
	end

	def receive _api, msg
		if User.in_blacklist? msg.from
			_api.send_message(chat_id: msg.chat.id, text: "Вы в черном списке. Если Вы попали туда случайно обратитесь к админу @scientistnik")
			return
		end

		@user = User.new msg.from
		@api = _api

		case msg
		when Telegram::Bot::Types::Message
			message msg
		when Telegram::Bot::Types::CallbackQuery
			callback msg
		end
		
		user = api = nil
	end

	def admin?() user.id == conf[:admin].id end

	def send_message text, hash={}
		hash[:text] = text
		hash[:chat_id] = user.tid if !hash.key? :chat_id
		api.send_message hash
	end

	def message msg
		case msg.text
		when '/start'; send_message "Что Вас интересует?", reply_markup: first_RKM
		when '/stop'
			if admin?
				send_message 'Ухожу в сон. Всем пока!'
				conf[:cycle] = false
			else
				send_message 'Sorry to see you go :(', reply_markup: RKR.new(remove_keyboard: true)
			end
		when '✉️ Мои объявления'
			kb = []
			user.announces.each do |ann|
				kb << IKB.new(text: "Вы отдаете #{ann.give}, получаете #{ann.get}", callback_data: "ann-edit_#{ann.id}")
			end
			if kb.empty?
				send_message 'У Вас нет объявлений'
			else
				send_message 'Вот Ваши объявления:', reply_markup: IKM.new(inline_keyboard: kb)
			end
		when /^.?.? bit/
			asset = Asset.get msg.text[/bit.*/]
			kb = []
			arr_col = [ IKB.new(text: asset.name, callback_data: "sell_#{asset.name}")]
			Asset.all_without(asset).each do |as|
				next if as.name[/^bit/]
				size = Announce.count_pair asset.id, as.id
				arr_col << IKB.new(text: "#{as.name} (#{size})", callback_data: "pair_#{as.name}_#{asset.name}")
				if arr_col.size == 2
					kb << arr_col
					arr_col = []
				end
			end
			kb << arr_col if arr_col.size > 0
			send_message "‼️Что вы хотите отдать?‼️\n\nЕсли в данном списке не хватает нужного пункта, пожалуйста напишите мне. Прям тут напишите!", reply_markup: IKM.new(inline_keyboard: kb)
		when /^.?.? Кошелек/
			send_message "Данная опция проходит стадию тестирования....Если хотите принять участие в тестировании просто напишитемне...прям тут..."
		else
			if !user.status.nil? && user.status[/^new_/]
				give, get = user.status.split('_')[1..-1].map {|e| Asset.get e}
				Announce.create user.id, give.id, get.id, message.text
				user.status = nil
				send_message 'Сообщение сохранено. Спасибо!'
			elsif admin?
				if user.status.nil? || user.status.empty?
					kb = []
					kb << IKB.new(text: 'Показать пользователей', callback_data: "admin-show-users")
					send_message 'Доброго времени суток, хозяин! Кому-то хотите написать?', reply_markup: IKM.new(inline_keyboard: kb)
				elsif user.status[/^send-msg_/]
					uname = User.new uid: user.status[9..-1]
					send_message msg.text, chat_id: uname.tid
					send_message "Сообщение отправлено!"
					user.status = nil
				end
			else
				send_message "Что Вас интересует?", reply_markup: first_RKM
				send_message "Пользователь #{user} написал боту: #{msg.text}", chat_id: conf[:admin].tid
			end
		end
	end
	
	def callback msg
		call = msg.data
		case call
		when 'admin-show-users'
			kb = []
			arr_col = []
			User.all.each do |u|
				arr_col << IKB.new(text: "@#{u.name}", callback_data: "admin-send_#{u.id}")
				if arr_col.size == 4
					kb << arr_col
					arr_col = []
				end
			end
			kb << arr_col if arr_col.size > 0
			send_message "Кому написать?", reply_markup: IKM.new(inline_keyboard: kb)

		when 'admin-cancel-send'
			user.status = nil
			send_message "Отменено..."
		
		when /^admin-send_/
			uname = User.new uid: call[11..-1]
			user.status = "send-msg_#{uname.id}"
			kb = []
			kb << IKB.new(text: "Отменить", callback_data: 'admin-cancel-send')
			send_message "Что пользователю #{uname.name} написать?", reply_markup: IKM.new(inline_keyboard: kb)

		when /^sell_/
			asset = Asset.get call.split("_")[-1]
			kb = []
			arr_col = []
			Asset.all_without(asset).each do |get|
				next if get.name[/^bit/]
				size = Announce.count_pair get.id, asset.id
				arr_col << IKB.new(text: "#{get.name} (#{size})", callback_data: "pair_#{asset.name}_#{get.name}")
				if arr_col.size == 2
					kb << arr_col
					arr_col = []
				end
			end
			kb << arr_col if arr_col.size < 2
			send_message "Вы отдаете #{asset.name}. ‼️Что Вы хотите получить?‼️\n\nЕсли в данном списке не хватает пункта, пожалуйста обратитесь к администратору бота @scientistnik", reply_markup: IKM.new(inline_keyboard: kb)

		when /^ann-new_/
			give, get = call.split('_')[1..-1].map {|e| Asset.get e}
			user.status = "new_#{give.name}_#{get.name}"
			send_message "Напишите объявление:\n\nПожалуйста укажите в объявлении следующие пункты:\n1. Курс обмена. Из объявления должно быть понятно, сколько Вы готовы отдать, а сколько получить.\n2. Количественное ограничение. Если Вы готовы к обмену имея ограничения на минимальный и/или максимальный объем, укажите это!\n3. Укажите время в течении которого Вы оперативно сможите осуществить обмен. Не забудьте указать часовой пояс!"

		when /^ann-show_/
			ann = Announce.get_id call.split('_')[-1]
			if !ann.id.nil?
				kb = []
				kb << IKB.new(text: 'Начать обмен', callback_data: "change_#{ann.give}_#{ann.get}_#{ann.user.id}")
				send_message "Объявление @#{ann.user}, он отдает #{ann.give}, получает #{ann.get}:\n\n#{ann.message}", reply_markup: IKM.new(inline_keyboard: kb)
			else
				send_message "Объявление @#{name} по обмену #{para} не найдено!"
			end

		when /^ann-edit_/
			ann = Announce.get_id call.split("_")[-1]
			kb = [[IKB.new(text: 'Редактировать', callback_data: "ann-new_#{ann.give}_#{ann.get}"),IKB.new(text: 'Удалить', callback_data: "ann-del_#{ann.id}")]]
			send_message ann.message, reply_markup: IKM.new(inline_keyboard: kb)

		when /^ann-del_/
			Announce.del call.split('_')[-1]
			send_message 'Объявление удалено'

		when /^change_/
			give_nm, get_nm, user_id = call.split('_')[1..-1]
			give = Asset.get give_nm
			get = Asset.get get_nm
			chuser = User.new uid: user_id
			send_message "Пользователь @#{user.name} хочет произвести обмен #{get} на #{give}! Свяжитесь с ним для обмена!", chat_id: chuser.tid

			kb = []
			bot.api.send_message(chat_id: message.from.id, text: "Пользователь @#{chuser.name} извещен! Свяжитесь с ним для обмена!") #, reply_markup: markup)

		when /^pair_/
			give, get = call.split('_')[1..-1].map {|e| Asset.get e}
			arr = Announce.get_all giveas: get.id, getas: give.id
			kb = []
			arr_col = []
			arr.each do |ann|
				arr_col << IKB.new(text: "@#{ann.user}", callback_data: "ann-show_#{ann.id}")
				if arr_col.size == 2
					kb << arr_col
					arr_col = []
				end
			end
			kb << arr_col if arr_col.size > 0
			kb << IKB.new(text: '📊 Безопасный обмен', callback_data: "bot-new_#{give}_#{get}")
			kb << IKB.new(text: 'Создать свое объявление', callback_data: "ann-new_#{give}_#{get}")
			if arr.empty?
				send_message "Нет подходящих вариантов. \n\nВы можете осуществить сделку через бота или добавить собственное объявление.", reply_markup: IKM.new(inline_keyboard: kb)
			else
				send_message 'Доступные', reply_markup: IKM.new(inline_keyboard: kb)
			end

		when /^bot-new_/
			give, get = call.split('_')[1..-1].map {|e| Asset.get e}
			send_message "Пользователь @#{user} хочет поменять #{give} на #{get}", chat_id: conf[:admin].tid
			send_message "📊 Безопасный обмен\n\n‼️Это обмен между часными лицами с частичным или полным участием бота.‼️\n\n Обмен происходит в три этапа:\n\n1. Владелец bitAsset пересылает на аккаунт бота желаемый объем bitAsset для обмена и указывает номер карточки. \n2. Покупатель bitAsset переводит средства на карточку.\n3. После подтверждения перевода средств, бот переводит bitAsset в заданный аккаунт.\n\nКомиссию бот берет у желающего приобрести bitAsset. \n\nНа данный момент, комиссия составляет 10 рублей."
		else
			p "Неверный запрос)))"
		end
	end
end
