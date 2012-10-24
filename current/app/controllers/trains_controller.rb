class TrainsController < ApplicationController

	def find
		#@train = Train.find([1])
		#Train.all.each do |train|
         # @train = train['name']
      	#end
      	@train = Train.where("location = '81700'")
	end
	def rawdata
		
        @out2 =[]
        @train = Train.where("location = '81700'")
        @out = Train.all
        @out.each do |oo|
          @out2 = @out2 << [oo['name'],oo['location'],oo['time']]
        end
        in_array = @out2
        out_array = []
        out_array = out_array.push(in_array[0])
        in_size = in_array.size
        out_size = 1
        (1..in_size-1).each do |count_row|
          counter = 0
          (0..out_size-1).each do |check_row|
            if out_array[check_row][0] == in_array[count_row][0]
              stop = true
              out_array[check_row] = out_array[check_row] + in_array[count_row]
              else
                counter = counter + 1
                end
          end
            if counter == out_size
              out_array = out_array << in_array[count_row]
              out_size = out_size + 1
            end
          end
        sort_by_time = out_array
        train_row = 0
        (0..out_size-1).each do |train_row|
          x = []
          (0..27).each do |rr|
            x[rr] = []
          end
          (0..27).step(3) do |ro|
            if sort_by_time[train_row][ro+2] != nil
              (0..2).each do |i|
                x[ro+i].insert(0,(sort_by_time[train_row][ro+i]))
              end
            else
              x[ro] = [0]
              x[ro+1] = [0]
              x[ro+2] = [0]
            end
          end
        x = x.flatten
         (0..10).each do |times|
           (0..24).step(3) do |ro|
             test5 = 3600*x[ro+5].to_s[0..1].to_i+ 60*x[ro+5].to_s[3..4].to_i+ x[ro+5].to_s[6..7].to_i
             test2 = 3600*x[ro+2].to_s[0..1].to_i+ 60*x[ro+2].to_s[3..4].to_i+ x[ro+2].to_s[6..7].to_i
@out3=test5
@out4 = test2
             if test5>test2
               temp1 = x[ro+3]
               temp2 = x[ro+4]
               temp3 = x[ro+5]
               x[ro+3]=x[ro]
               x[ro+4]=x[ro+1]
               x[ro+5]=x[ro+2]
               x[ro] = temp1
               x[ro+1] = temp2
               x[ro+2] = temp3
             end
           end
         end
        (0..27).each do |i|
          sort_by_time[train_row][i] = x[i]
        end
        end

       order_trains = sort_by_time
       order_size = order_trains.size
       @out3 = order_trains[1]
       (0..10).each do |times|
           (0..order_size-2).each do |ro|
             test0 = 3600*order_trains[ro][2].to_s[0..1].to_i+ 60*order_trains[ro][2].to_s[3..4].to_i+ order_trains[ro][2].to_s[6..7].to_i
             test1 = 3600*order_trains[ro+1][2].to_s[0..1].to_i+ 60*order_trains[ro+1][2].to_s[3..4].to_i+ order_trains[ro+1][2].to_s[6..7].to_i
             @out3 = test0
             @out4 = test1

             if test1>test0
               temp1 = order_trains[ro]
               temp2 = order_trains[ro+1]
               order_trains[ro] = temp2
               order_trains[ro+1] = temp1                        
#temp3 = x[ro+5]
               #x[ro+3]=x[ro]
               #x[ro+4]=x[ro+1]
               #x[ro+5]=x[ro+2]
               #x[ro] = temp1
               #x[ro+1] = temp2
               #x[ro+2] = temp3
             end
           end
         end
        (0..27).each do |i|
          #sort_by_time[train_row][i] = x[i]
        end


        out_array = sort_by_time
        @out2 = out_array
        end


end
