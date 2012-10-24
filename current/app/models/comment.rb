class Comment < ActiveRecord::Base
  attr_accessible :location, :name, :time
end
