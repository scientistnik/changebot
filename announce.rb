require_relative 'user'
require_relative 'assets'

class Announce
	TABLE = 'announces'
	attr_reader :id, :user, :give, :get, :message

	def initialize arr
		@id, @user, @give, @get, @message = arr
		@user = User.new uid: @user
		@give = Asset.get_id @give
		@get = Asset.get_id @get
	end

	class << self
		def get_all h
			Model.get_where(TABLE, h).inject([]) {|r,a| r << Announce.new(a)}
		end

		def get_user user_id
			Model.get_where(TABLE, uid: user_id).inject([]) {|r,a| r << Announce.new(a)}
		end

		def get_id ann_id
			Announce.new Model.get_where(TABLE, anid: ann_id).first
		end

		def count_pair give_id, get_id
			Model.get_where(TABLE,'count(*)',giveas: give_id, getas: get_id).first.first
		end

		def create user_id, give_id, get_id, txt
			if Model.exist? TABLE, uid: user_id, giveas: give_id, getas: get_id
				Model.update TABLE, {antext: txt}, {uid: user_id, giveas: give_id, getas: get_id} 
			else
				Model.insert TABLE, uid: user_id, giveas: give_id, getas: get_id, antext: txt
			end
		end

		def del ann_id
			Model.delete TABLE, anid: ann_id
		end
	end
end
