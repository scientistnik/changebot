require_relative 'model'

class User
	attr_reader :id, :name, :tid, :karma
	attr_accessor :status

	TABLE = 'users'

	def initialize user
		if user.is_a? Telegram::Bot::Types::User
			arr = Model.get_once TABLE, {username: user.username}
			Model.insert(TABLE, username: user.username, tid: user.id, karma: 0) if arr.nil?
			user = {username: user.username}
		end
		arr = Model.get_once TABLE, user

		@id, @name, @tid, @status, @karma = *arr
	end

	def self.exist? name
		Model.exist? TABLE, username: name
	end

	def self.in_blacklist? user
		Model.exist? 'blacklist', tid: user.id
	end

	def status= new_stat
		@status = new_stat
		Model.update TABLE, {status: @status}, {uid: @id}
	end

	def announces
		Announce.get_user self.id
	end

	def to_s() @name end

	def self.all
		Model.get_all(TABLE,'username').inject([]) {|r,e| r << User.new(username: e.first) }
	end
end
