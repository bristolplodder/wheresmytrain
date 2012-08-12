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
while true
@msg = @conn.receive
$stdout.print @msg.body

json2 = @msg.body
print "\n"
rubydoc2 = JSON.parse json2


if rubydoc2[0]["header"]["msg_type"] == 0003
print "train_id: "
@name = rubydoc2[0]["body"]["train_id"]
print "   loc_stanox:   "
@location = rubydoc2[0]["body"]["loc_stanox"]
print "   time:   "
@time = rubydoc2[0]["body"]["planned_timestamp"]
print "\n"
#else
#   print "not 0003"
end



$stdout.flush
@conn.ack @msg.headers["message-id"]
end
@conn.disconnect
rescue
end