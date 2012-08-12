require 'sqlite3'
require 'rubygems'
require 'stomp'
require 'json/pure'
require 'mysql'  

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


  
#my = Mysql.new(hostname, username, password, databasename)  
con = Mysql.new('localhost', 'root', '', 'train_db')  

def Is_Bristol(x)
[81700 ,81103 ,81109 ,81305 ,81403 ,81422 ,81813 ,81819 ,81903 ,81905].include?(x)
# 81116 ,81507 ,81503 ,81501 ,81906 ,81909 ,81911 ,81260 , 81261, 81259 ,81255 ,81240 ,81230 ,81211
end

for i in 0..1000
#while true
@msg = @conn.receive
#$stdout.print @msg.body


if @msg.body != [] 

json2 = @msg.body
print "\n"
#print json2
rubydoc2 = JSON.parse json2
#end
@location = rubydoc2[0]["body"]["loc_stanox"]
if Is_Bristol(@location.to_i)



@test =  "test"

#if rubydoc2[0]["header"]["msg_type"] == 0003
print "train_id: "
@name = rubydoc2[0]["body"]["train_id"][2..5]
print @name
#print @name.inspect
print "   loc_stanox:   "

print @location
#print @location.class
print "   time:   "
@time = (rubydoc2[0]["body"]["planned_timestamp"].to_i/1000).to_i
@time = (Time.at(@time).to_s[11..12].to_i-1).to_s+Time.at(@time).to_s[13..19]

print @time
#print @time.class
#print "\n"
#else
#   print "not 0003"
#end

#database.execute "INSERT into latest (name,location,time) VALUES (1,2,3) "

puts Is_Bristol(@location.to_i)


 con.query ("INSERT into trains (name,location,time) VALUES ('#{@name}','#{@location}','#{@time}') ")
end
 
end

$stdout.flush
@conn.ack @msg.headers["message-id"]
end
@conn.disconnect
rescue
end

 
rs = con.query('select * from trains')  


rs.each_hash { |h| puts h['name'], h['location'], h['time']}  
con.close
 
#rows = database.execute ("select * from latest") 
 
#p rows


