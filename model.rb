require 'sqlite3'

module Model
	class << self
		def init_db 
			@db = SQLite3::Database.new 'data.db'
			f = File.open 'init.db','r'
			f.read.split(';').each do |sql|
				next if sql == "\n"
				@db.execute sql+';'
			end
			f.close
			@db
		end

		def get_where *args, where 
			@db ||= init_db
			table = args.shift
			@db.execute "select #{args.empty? ? '*' : args.join(',')} from #{table} where #{where.inject("") {|s,(k,v)| s + " #{k}='#{v}' and"}[0...-3]};"
		end

		def get_all table, *select
			@db ||= init_db
			@db.execute "select #{select.join(',')} from #{table};"
		end

		def get_once table, where
			@db ||= init_db
			@db.execute("select * from #{table} where #{where.inject("") {|s,(k,v)| s + " #{k}='#{v}' and"}[0...-3]};").first
		end

		def exist? table, where
			@db ||= init_db
			@db.execute("select 1 from #{table} where #{where.inject("") {|s,(k,v)| s + " #{k}='#{v}' and"}[0...-3]};").any?
		end

		def insert table, hash
			@db ||= init_db

			keys = []
			vals = []
			hash.each_pair {|k,v| keys << k; vals << v}

			@db.execute "insert into #{table}(#{keys.join(',')}) values(\"#{vals.join('","')}\");"
		end

		def update table, *arr 
			@db ||= init_db
			hash, where = arr

			@db.execute "update #{table} set %s='%s' where #{where.inject("") {|s,(k,v)| s + " #{k}='#{v}' and"}[0...-3]};" % hash.first
		end

		def delete table, where
			@db ||= init_db
			@db.execute "delete from #{table} where #{where.inject("") {|s,(k,v)| s + " #{k}='#{v}' and"}[0...-3]};"
		end
	end	
end
