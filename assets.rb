class Asset
	attr_reader :id, :name
	TABLE = 'assets'

	def initialize args
		@id = args.shift
		@name = args.shift
	end

	def to_s() @name end

	class << self
		def all
			Model.get_all(TABLE, '*').inject([]) {|r,a| r << Asset.new(a) }
		end

		def all_without asset
			Model.get_where(TABLE, 'not asid': asset.id).inject([]) {|r,a| r << Asset.new(a)}
		end

		def get name
			obj = Model.get_once TABLE, name: name
			raise "NotFoundAsset" if obj.nil?
			Asset.new obj
		end

		def get_id id
			obj = Model.get_once TABLE, asid: id
			raise "NotFoundAsset" if obj.nil?
			Asset.new obj
		end
	end
end
