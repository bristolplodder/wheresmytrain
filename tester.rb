require 'mysql'  
  
#my = Mysql.new(hostname, username, password, databasename)  
con = Mysql.new('localhost', 'root', '', 'train_db')  
rs = con.query('select * from all_trains')  
rs.each_hash { |h| puts h['name']}  
con.close  
