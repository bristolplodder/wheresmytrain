#require 'sqlite3'
require 'rubygems'
require 'stomp'
require 'json/pure'
require 'mysql'  
require 'time'
require 'date'
require 'tzinfo'

(0..10).each do |i| 
puts "restart: "
puts i

begin
@port = 61618
@host = "datafeeds.networkrail.co.uk"
@user = "XXX"
@password = "XXX"
@destination = "/topic/TRAIN_MVT_EF_TOC"
$stderr.print "Connecting to stomp://#{@host}:#{@port} as #{@user}\n"
@conn = Stomp::Connection.open @user, @password, @host, @port, true
$stderr.print "Getting output from #{@destination}\n"
@conn.subscribe @destination, { :ack =>"client" }

#my = Mysql.new(hostname, username, password, databasename)
con = Mysql.new('localhost', 'XXX', 'XXX', 'XXX')



def Is_Bristol(x)
[81700 ,81103 ,81109 ,81305 ,81403 ,81422 ,81813 ,81819 ,81903 ,81905, 81116 ,81507 ,81503 ,81501 ,81906 ,81909 ,81911 ,81260 , 81261, 81259 ,81255 ,81240 ,81230 ,81211].include?(x)
end

utc = Time.new 
puts "utc "
puts  utc.hour
#for i in 0..50
tz = TZInfo::Timezone.get('Europe/London')
t=tz.now
hr=t.hour
today = Date.today.wday
puts "day:" 
puts today
if today == 7
puts "waiting due to late Sunday start" 
sleep(3600)
end

if utc.hour == hr
puts "waiting due to not BST"
sleep(3600)
end

while hr !=1

tz = TZInfo::Timezone.get('Europe/London')
t=tz.now
hr=t.hour
m=t.min
s=t.sec

print "minute: "
print m

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

print "current time:"
print hr
print ":"
print m
print ":"
print s
print "\n"

print "train_id: "
@name = rubydoc2[0]["body"]["train_id"][2..5]
print @name
#print @name.inspect
print "   loc_stanox:   "

print @location
#print @location.class
print "   time:   "
@time = (rubydoc2[0]["body"]["planned_timestamp"].to_i/1000).to_i
@time = (Time.at(@time).to_s[11..12].to_i).to_s+Time.at(@time).to_s[13..19]

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
 
print m


if  m == 0 || m == 15 || m == 30 || m == 45


rs = con.query('select * from trains')

rs.each_hash { |h|
 puts h['id'],h['name'],h['location'], h['time']

hs =h['time'].to_s[0..1]
ms =h['time'].to_s[3..4]
puts "hs",hs,"  ","hr",hr
puts "ms", ms, " ","m",m
puts hs+"  "+h['id']

@idout = h['id'].to_i
puts "idout",@idout

ts = hs.to_i*60 + ms.to_i
tt = hr.to_i*60 + m

if (ts+15)<tt
con.query "DELETE FROM trains WHERE id IN ('#{@idout}')"
puts "delete", "ts: ", ts,"tt", tt, "hs", hs, "hr", hr
end

}

test = con.query('select * from trains')
test.each_hash { |h|

puts "test"
puts h 
if h == nil
con.query("INSERT into trains (name, location,time) VALUES ('XXXX','no reports','#{@time}')")
end
}

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

sleep(900)
end 
#rows = database.execute ("select * from latest") 
 
#p rows


