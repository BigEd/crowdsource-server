require 'rubygems'
require 'sinatra'
require 'digest/sha1'
require 'dm-core'
require 'dm-validations'
require 'haml'
require 'sass'
require 'models'
require 'time'
require 'pp'
require 'fast-aes'
require 'clipper'

@@secret = FastAES.new("changemechangmec")
enable :sessions

#temp db hack 
##http://www.mail-archive.com/datamapper@googlegroups.com/msg00263.html
class DataObjects::Sqlite3::Command
  alias original_execute_non_query execute_non_query
  alias original_execute_reader execute_reader

  def execute_non_query(*args)
    try_again = 0
    begin
      original_execute_non_query(*args)
    rescue DataObjects::SQLError => e
      raise unless e.message =~ /locked/ || e.message =~ /busy/

      if try_again < 10
        try_again += 1
        #VipLog.debug "locked or busy - retrying (#{try_again})"
        retry
      else
        raise
      end
    end
  end

  def execute_reader(*args)
    try_again = 0
    begin
      original_execute_reader(*args)
    rescue DataObjects::SQLError => e
      raise unless e.message =~ /locked/ || e.message =~ /busy/

      if try_again < 5
        try_again += 1
        retry
      else
        raise
      end
    end
  end
end



# SASS stylesheet
get '/stylesheets/style.css' do
  headers 'Content-Type' => 'text/css; charset=utf-8'
  sass :style
end

### Index
get '/' do
  authorized?
  haml :index
end

########################
#routing 
get '/user/*' do
  protected!
  pass  
end
post '/user/*' do
  protected!
  pass  
end
put '/user/*' do
end
get '/admin/*' do
  admin!
  pass
end
post '/admin/*' do
  admin!
  pass
end
########################
#login
get '/register' do
  haml :register
end

post '/register' do
  username = params[:username].match(/[A-Za-z0-9]*/).to_s
  email = params[:email].match(/[\.A-Za-z0-9]*@[A-Za-z0-9\.]*/).to_s
    
  if(params[:password] == params[:password2])
    unless User.first(:name => username)
      u = User.create
      u.name = username
      u.email = email
      u.admin = false
      u.points = 0
      u.location = params[:location]
      u.real_name = params[:realname]
      u.salt = rand_string(10)
      u.hashpass = Digest::SHA1.hexdigest(params[:password]+u.salt)
      puts "SAVING USER"
      error("Something went wrong") if not u.save
    else
      error("User already exists")
    end
  else
    error("Your password confirmation did not match")
  end
  
  haml :index
end

post '/login' do
  username = params[:username]
  password = params[:password]
  
  u = User.first(:name => username)                
  unless u == nil
    if u.hashpass == Digest::SHA1.hexdigest(password+u.salt)
      #create the users session
      blob = "#{Time.now.to_i}\xff#{username}"
      session["hash"] = Digest::SHA1.digest(blob) + @@secret.encrypt(blob)
      @user = u
    else
      error("Wrong credentials buddy")
    end
  else
    error("Wrong credentials buddy")
  end

  haml :index
end

get '/logout' do
	session["hash"] = nil
	redirect '/'
end
########################
#user management
get '/user/changepass' do
  haml :changepass
end

post '/user/changepass' do
  if @user.hashpass == Digest::SHA1.hexdigest(params[:oldpass]+@user.salt)
#    if params[:newpass].any? and (params[:newpass] == params[:newpass2])
     if (params[:newpass] == params[:newpass2])
      #note -> salt is being reused
      @user.hashpass = Digest::SHA1.hexdigest(params[:newpass]+@user.salt)
      if @user.save
        @errors = "Successfully changed password"
      else
        @errors = "Failed to save, contact admin"
      end
    else
      @errors = "New passwords dont match"
    end
  else
    @errors = "Wrong password"
  end
  haml :changepass
end


########################
### admin - Users
get '/admin/user/list' do
  @users = User.all
  haml :user_list
end

get '/admin/user/edit/:id' do
  if params[:id] == "new"
    @target = User.create
  else
    @target = User.first(:id => params[:id])
  end
  haml :user_edit
end

post '/admin/user/edit' do
  @target = User.first(:id => params[:id])
  data = params[:user]
  
  @target.name = data[:name] 
  @target.email = data[:email]
  
  if data[:admin] == "on"
    if @target.name != "admin"
      @target.admin = !@target.admin
    else
      @errors = "can not toggle admin user"
    end
  end
  
  if data[:reset_password]
    puts "would reset password"
  end

  @errors = "Something went wrong" if not @target.save

  @users = User.all
  haml :user_list
end

get '/admin/user/delete/:id' do
  @target = User.first(:id => params[:id])
  unless @target.name == 'admin'
    @target.destroy
  end
  redirect '/admin/user/list'
end

########################
### Chips, Layers, and Tiles
get '/user/chips' do
  @chips = Chip.all
  haml :chip_list
end

get '/user/chip/:id' do
  @chip = Chip.first(:id =>params[:id])
  haml :chip_view
end

get '/user/chip/:id/:layer' do
  @chip = Chip.first(:id =>params[:id])
  @layer = Layer.first(:id => params[:layer])
  session[:x] ||= 1
  session[:y] ||= 1
  haml :chip_view
end

get '/user/chip/:id/:layer/:direction' do
  @chip = Chip.first(:id =>params[:id])
  @layer = Layer.first(:id => params[:layer])

  session[:x] ||= 0
  session[:y] ||= 0

  if params[:direction] == "left"
    session[:x] -= 1
  elsif params[:direction] == "right"
    session[:x] += 1
  elsif params[:direction] == "up"
    session[:y] -= 1
  elsif params[:direction] == "down"
    session[:y] += 1
  elsif params[:direction] == "start"
    session[:x] = 1
    session[:y] = 1
  end
  haml :chip_view
end


get '/admin/chip/edit/:id' do
  if params[:id] == "new"
    @target = Chip.create
  else
    @target = Chip.first(:id => params[:id])
  end
  haml :chip_edit
end

post '/admin/chip/edit' do
  @target = Chip.first(:id => params[:id])
  data = params[:chip]

  @target.name = data[:name]
  @target.wikiURL = data[:wikiURL]
  @target.description = data[:description]
  @target.maxx = data[:maxx]
  @target.maxy = data[:maxy]
  @errors = "Something went wrong" if not @target.save
  redirect '/user/chips'
end

get '/admin/chip/delete/:id' do
  @target = Chip.first(:id => params[:id])
  @target.destroy
  redirect '/user/chips'
end

get '/admin/chip/export/:id' do
  #dump out file of rectangle information
  @chip = Chip.first(:id => params[:id])  
  if @chip
    @best_layers = get_best_submissions(@chip)
  else
    @errors = "Wrong chip id"
    redirect '/user/chips/'
  end
  haml :best_tiles
end

get '/admin/layer/edit/:chipid/:id' do
  chip = Chip.first(:id =>params[:chipid])
  if params[:id] == "new"
    @target = Layer.create
    @target.chip_id = chip.id
  else
    @target = Layer.first(:id => params[:id])
  end
  haml :layer_edit
end

post '/admin/layer/edit' do
  @target = Layer.first(:id => params[:id])
  data = params[:layer]

  @target.name = data[:name]
  @target.chip_id = data[:chip_id]
  @target.itype = data[:itype]
  @target.short_text = data[:short_text]
  @target.long_text = data[:long_text]
  @target.thumbnail = data[:thumbnail]
  @errors = "Something went wrong" if not @target.save
  redirect '/user/chips'
end

get '/admin/layer/delete/:id' do
  @target = Layer.first(:id => params[:id])
  @target.destroy
  redirect '/user/chips'
end


get '/user/tile/:layer_id/:x/:y' do
  @tile = Tile.first(:layer_id => params[:layer_id], 
                    :x_coord => params[:x],
                    :y_coord => params[:y])
  
  if @tile
    layer = Layer.first(:id=>@tile.layer_id)
  else
    redirect '/tiles/missing.png'
  end
  
  redirect "/tiles/#{layer.chip_id}/#{@tile.y_coord}-#{@tile.x_coord}#{layer.itype}.png"
end

########################
### Game and Submissions
get '/user/game' do
  @pending = Submission.all(:user_id=>@user.id, :state=> "pending")
  @complete = Submission.all(:user_id=>@user.id, :state=> "complete")
  haml :game_index
end

get '/user/game/new_tile' do
  #pick a random layer on a random chip
  @layer = (Layer.all.sort_by {rand}).first
  @tile = (Tile.all(:layer_id=>@layer.id).sort_by {rand}).first
  @sub = Submission.create

  @sub.state = "pending"
  @sub.user_id = @user.id
  @sub.tile_id = @tile.id
  @sub.quality_factor = 0
  @sub.initial_score = 0
  @sub.bonus_score = 0
  
  @sub.save
  
  session[:x] = @tile.x_coord
  session[:y] = @tile.y_coord
  haml :game_view
end

get '/user/submission/load/:sub_id' do
  @sub = Submission.first(:user_id=>@user.id, :id=>params[:sub_id])
  if @sub
    @tile = Tile.first(:id=>@sub.tile_id)
    @layer = Layer.first(:id=>@tile.layer_id)
    session[:x] = @tile.x_coord
    session[:y] = @tile.y_coord
    haml :game_view
  else
    @errors = "could not find submission"
    redirect '/user/game'
  end
end

get '/user/submission/submit/:sub_id' do
  @sub = Submission.first(:user_id=>@user.id, :id=>params[:sub_id])
  if @sub
    score_submission(@sub)
    @sub.state = "complete"
    if @sub.save
      redirect "/user/submission/load/#{@sub.id}"
    else
      @errors = 'failed to save score'
    end
  else
    @errors = "could not find submission"
  end
  redirect '/user/game'
end

get '/user/submission/delete/:sub_id' do
  sub = Submission.first(:user_id=>@user.id, :id=>params[:sub_id])
  if sub
    sub.destroy
  else
    @errors = "could not find submission"
  end
  redirect '/user/game'
end

get '/submission/:user_id/:sub_id' do
 #load tile info
 s = Submission.first(:id=>params[:sub_id], :user_id=>params[:user_id])

 redirect '/', 400 if not s

 s.rawdata #oh jaa
end

put '/submission/:user_id/:sub_id' do
  s = Submission.first(:id=>params[:sub_id], :user_id=>params[:user_id])  
  
  if s
    data = request.body.read
    s.rawdata = data
    if not s.save
      pp s.errors
      redirect '/', 500
    end
  else
    redirect '/', 400 #bad request
  end
  
  "OK"  
end

#######################
helpers do
  def error(str)
    @errors = str
  end

  def rand_string(n)
    alphabet = (('a'..'z').to_a+('A'..'Z').to_a+('0'..'9').to_a)
    return (0...n).map{ alphabet.to_a[rand(62)] }.join
  end

  def admin!  
    unless authorized? and @user.admin
      throw(:halt, [401, "Not authorized\n"])
    end
  end

  def protected!
    unless authorized?
      throw(:halt, [401, "Not authorized\n"])
    end
  end

  def authorized?
    #TODO->switch to HMAC

    #currently doing HASH|CRYPTED
    # H(decrypt(CRYPTED)) == HASH
    return false if not session["hash"]

    text = session["hash"][20..-1]
    hash = session["hash"][0..19]
    #stateless sessions. 
    data = @@secret.decrypt(text)

    if Digest::SHA1.digest(data) == hash
      expiration, username = data.split("\xff",2)
      #1 day sessions
      if Time.now.to_i - expiration.to_i < 24*60*60
        @user = User.first(:name => username)
        return true
      end
    end
    false
  end


########################
#tile submission scoring

class Numeric
  def degrees
    #monkey patch conversion
    self * Math::PI / 180
  end
end

  def to_rects(rawdata)
    shapes = []

    rawdata.lines do |line|
      parts = line.split
      if parts[0] == 'l'
        #form is X1, Y1    X2, Y2,    width
        xA,yA,xB,yB,width = parts[1..-1].map(&:to_i)

        yA += 0.00001 if yA == yB
        xA += 0.00001 if xA == xB
                  
        h = ((xA-xB)**2 + (yA-yB)**2)**0.5
        angle1 = Math::asin((yB-yA)/h)
        angle2 = Math::PI/2.0 - angle1
        
        widthA = width*0.5 * Math::cos(angle2)
        widthB = width*0.5 * Math::tan(angle2)
        
        x1 = xA - widthA
        y1 = yA - widthB
        x2 = xA + widthA
        y2 = yA + widthB
        x3 = xB - widthA
        y3 = yB - widthB
        x4 = xB + widthA
        y4 = yB + widthB
        
        puts '====='
        pp xA,yA,"--",xB,yB
        pp [[x1,y1],[x2,y2],[x3,y3],[x4,y4]]
        puts '====='
        
        
        shapes.push [[x1,y1],[x2,y2],[x3,y3],[x4,y4]]
      elsif parts[0] == 'r'
        #form is X1, Y1    X2, Y2
        x1,y1,x2,y2 = parts[1..-1].map(&:to_i)
        x3 = x2
        y3 = y1
        x4 = x1
        y4 = y2        
        shapes.push [[x1,y1],[x2,y2],[x3,y3],[x4,y4]]
      else
        raise "unknown type..."
      end

    end
    return shapes
  end
  
  def get_width_defects(sub)
    
  end
  
  def get_overlap_defects(shapes)
    defect = []
    (0..shapes.count-1).each do |i|
      (0..i-1).each do |j|
        c = Clipper::Clipper.new
        c.add_subject_polygon(shapes[i])
        c.add_clip_polygon(shapes[j])
        ret = c.intersection :non_zero, :non_zero

        defect.push ret if not ret.empty?
      end
    end
    pp defect
    puts "^^^^"
    return defect
  end
  
  def score_submission(sub)
    #@sub.quality_factor = 0
    #@sub.initial_score = 
    #@sub.bonus_score = 0
    
    #this sets the initial score
    score = 50
    
    shapes = to_rects(sub.rawdata)

=begin
    Spacing error - a gap is too small (two edges too close together)
    Width error - a feature is too small (two edges too close together)
    Redundancy - a shape is entirely covered by other shapes
    Too many or too few polygons, or rectangles (according to some broad range specific to the chip and layer)
=end
    #spacing_errors = get_spacing_defects()
    width_errors = get_width_defects(shapes)
    overlap_errors = get_overlap_defects(shapes)
    
    defect_penalty = 0
    defect_penalty += overlap_errors.count*10 if overlap_errors
    defect_penalty += width_errors.count*10 if width_errors

    score -= defect_penalty
    sub.initial_score = score
    sub.quality_factor = score
  end
########################
#tile exporting
  def get_best_submissions(chip)
    layers_out = {}
    Layer.all(:chip_id=>chip.id).each do |layer|
      layers_out[layer.id] = []
      Tile.all(:layer_id=>layer.id).each do |tile|
        choices = Submission.all(:state=>"complete", :tile_id => tile.id).sort_by {:quality_factor}
        layers_out[layer.id].push choices[0]
      end
    end
    layers_out
  end
  
end
