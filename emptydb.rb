#require sqlite3'
require 'rubygems'
require 'mysql'  


#my = Mysql.new(hostname, username, password, databasename)
con = Mysql.new('localhost', 'XXX', 'XXX', 'XXX')
con.query ('DELETE FROM trains')
con.close

