require 'dm-core'
require 'dm-validations'
require 'dm-timestamps'

DataMapper.setup(:default, "sqlite3://#{Dir.pwd}/db/development.db")

### MODELS
class User
  include DataMapper::Resource
  property :id,         Serial
  property :name,       String, :unique_index => true
  property :real_name,  String
  property :email,      String, :unique_index => true
  property :location,   String
  property :salt,       String
  property :hashpass,   String  # 'hash' is a restricted property
  property :points,     Integer
  property :promotion_level,     Integer
  property :quality_factor,     Integer
  property :admin,      Boolean 

  #team information
  property :team_id,  Integer
  
  property :created_at, DateTime
end

class Chip
  include DataMapper::Resource
  property :id,           Serial
  property :name,         String
  property :wikiURL,      Text
  property :description,  Text
  property :maxx,         Integer
  property :maxy,         Integer

  property :created_at, DateTime
end

class Layer
  include DataMapper::Resource
  property :id,           Serial
  property :name,         String
  property :chip_id,      Integer
  property :itype,        String
  property :short_text,   Text
  property :long_text,    Text
  property :thumbnail,    Text
  
  property :created_at, DateTime
end

class Tile
  include DataMapper::Resource
  property :id,       Serial
  property :layer_id, Integer
  
  #current tile mechanism
  property :x_coord,     Integer
  property :y_coord,     Integer

  #this represents some different mapping:
  property :minx,     Integer
  property :miny,     Integer
  property :sizex,    Integer
  property :sizey,    Integer

  property :jpeg,       Text
  property :png,        Text
  property :thumbnail,  Text

end

=begin
What is this?
class Photolayer
  include DataMapper::Resource
  property :id,      Serial
  property :name,    String
end
=end

class Submission
  include DataMapper::Resource
  property :id,             Serial
  property :user_id,        Integer
  property :tile_id,        Integer
  property :rawdata,        Text
  property :state,          String
  property :quality_factor, Integer
  property :initial_score,  Integer
  property :bonus_score,          Integer
  property :current_player_calibre,   Integer

  property :created_at, DateTime
end

class Line
  include DataMapper::Resource
  property :id,             Serial
  property :submission_id,  Integer
  property :data,           Text
  property :created_at, DateTime
end
