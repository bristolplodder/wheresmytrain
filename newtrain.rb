require 'rubygems'
require 'stomp'
require 'json/pure'
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
while true

#for i in 0..100
#   puts "Value of local variable is #{i}"
@msg = @conn.receive
$stdout.print @msg.body


json2 = @msg.body


print "\n"
rubydoc2 = JSON.parse json2
#$stderr.print "Location #"
#print i 

if rubydoc2[0]["header"]["msg_type"] == 0003
print "train_id: "
print rubydoc2[0]["body"]["train_id"]
print "   loc_stanox:   "
print rubydoc2[0]["body"]["loc_stanox"]
print "\n"
else
   print "not 0003"
end

$stdout.flush
@conn.ack @msg.headers["message-id"]
end
#end
@conn.disconnect
rescue
end