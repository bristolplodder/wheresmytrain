require 'sqlite3'
require 'rubygems'
require 'stomp'
begin
@port = 61618
@host = "datafeeds.networkrail.co.uk"
@user = "matthew.cockburn@blueyonder.co.uk"
@password = "Tr@1nd@t@"
@destination = "/topic/TRAIN_MVT_EF_TOC"
$stderr.print "Connecting to stomp://#{@host}:#{@port} as #{@user}\n"
@conn = Stomp::Connection.open @user, @password, @host, @port, true
$stderr.print "Getting output from #{@destination}\n"
@conn.subscribe @destination, { :ack =>"client" }
for i in 0..100
#while true
@msg = @conn.receive
$stdout.print @msg.body





$stdout.flush
@conn.ack @msg.headers["message-id"]
end
@conn.disconnect
rescue
end









database = SQLite3::Database.new( "train.database" )
 
#database.execute( "create table sample_table (id INTEGER PRIMARY KEY, name TEXT, location TEXT, time TEXT);" )
 
database.execute( "insert into sample_table (name, location, time) values ('3G33', 'Bristol', '1200')")
 
rows = database.execute( "select * from sample_table" )
 
p rows