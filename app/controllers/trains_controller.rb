class TrainsController < ApplicationController

	def find
		#@train = Train.find([1])
		#Train.all.each do |train|
         # @train = train['name']
      	#end
      	@train = Train.where("location = '81700'")
	end
	def rawdata
		
      	@train = Train.where("location = '81700'")
	end

end
