#! /usr/bin/env ruby

require 'rubygems'
require 'sinatra'
require 'common'
require 'date'

require 'RMagick'

SECRET_PASSWORD = 'grunties'
PATCHWORKW = 3
PATCHW = 150
PINCH = 100

HOOPHIC_COMMENTS = 'hoophic_comments'

MOBILE_USER_AGENTS = /android|palm|blackberry|nokia|phone|midp|mobi|symbian|chtml|ericsson|minimo|audiovox|motorola|samsung|telit|upg1|windows ce|ucweb|astel|plucker|x320|x240|j2me|sgh|portable|sprint|docomo|kddi|softbank|android|mmp|pdxgw|netfront|xiino|vodafone|portalmmm|sagem|mot-|sie-|ipod|up\.b|webos|amoi|novarra|cdm|alcatel|pocket|ipad|iphone|mobileexplorer|mobile/i
ROBOTICS = <<EOS
User-agent: *
Disallow: /
EOS

def uploadfile(path, id, params)
  if (data = params.delete(id))
	  dirname = File.dirname(path)
	  FileUtils.mkdir_p(dirname) unless File.directory?(dirname)
    File.unlink(path) if File.exist?(path)
    File.open(path, 'w') do |f|
      while blk = data[:tempfile].read(16384)
        f.write(blk)
      end
    end
  end
end

def uploadimg(path, id, params, format = 'png')
	if (data = params.delete(id))
		img = data[:tempfile].read
		im = Magick::Image.from_blob(img).first
	  img = im.to_blob { self.format = format } unless im.format[0] == format.upcase[0]
	  dirname = File.dirname(path)
	  FileUtils.mkdir_p(dirname) unless File.directory?(dirname)
    File.unlink(path) if File.exist?(path)
		File.open(path, 'w') { |f| f.write(img) }
		[im.columns.to_i, im.rows.to_i]
	end
end

def is_mobile_device?(agent)
	MOBILE_USER_AGENTS.match(agent)
end

helpers do
	def esc(s)
	  s.gsub(/"/, '&quot;').gsub(/_(.*?)_/m, "<i>\\1</i>").gsub(/\*(.*?)\*/m,"<b>\\1</b>").gsub(/(\r\n)/m, '<br/>').strip if s # " // help UE syntax highlighting
	end

  def highlightIndex
    @hi ||= @stories.index(@highlight)
  end

  def nextupIndex
    @ni ||= @stories.index(@nextup)
  end
end

def erb_stories(mob)
  erb (mob.blank? ? :stories : :mstories)
end

def locaterealimage(seriesname, nym, imtype, format)
  content_type 'image/' + (format == 'png' ? 'png' : 'jpeg')
  series = Series.first(:name => seriesname)
	if request.cookies[series.cookie_name] == series.passphrase or request.cookies[series.cookie_name] == SECRET_PASSWORD
		imagepath = File.join(Dir.pwd, 'images', seriesname, nym, "#{imtype}.#{format}")
		imagepath = File.join(Dir.pwd, 'images', seriesname, 'sysimage', "#{imtype}.#{format}") unless File.exist?(imagepath)
	 	File.open(imagepath, 'r') { |f| f.read }
	end
end

# restful methods

not_found do
  begin
    if request.path.match(/^\/images\/patchwork\/[^\.]+\.jpg$/)
		  images = []
		  ['ccps', 'eote', 'lotl', 'dotd'].each do |ser|
		    Series.first(:name => ser).stories.each do |story|
		      images << "#{Dir.pwd}/public#{story.absolute_image_path}" if story.img_available?
		    end
		  end
		  images.shuffle!

			h = images.length / PATCHWORKW
			nims = PATCHWORKW * h

		  puts "#{nims} images used of #{images.length}"

		  im = Magick::Image.new(PATCHWORKW*PATCHW, h*PATCHW)
		  images.each_with_index do |path,idx|
		    puts "Placing at #{idx%PATCHWORKW}, #{idx/PATCHWORKW}"
				i = Magick::Image.read(path).first
		    im.composite!(i.resize(PATCHW,PATCHW), (idx % PATCHWORKW)*PATCHW, (idx / PATCHWORKW)*PATCHW, Magick::CopyCompositeOp)
		  end
		  im.write("#{Dir.pwd}/public#{request.path}") { self.format = 'jpg' }
		  redirect request.path
    elsif request.path.match(/^\/images\/([^\/]+)\/([^\/]+)\//)
	    obj = Series.first(:name => $1)
  	  obj = obj.stories.first(:nym => $2) unless $2 == 'sysimage'
    	redirect obj.image_path(request.path)
    else
    	raise
    end
  rescue Exception => e
    puts e.message
    #puts e.backtrace.inspect
    halt 404, 'Exterminated'
  end
end

get '/patchwork.jpg' do
  redirect Dir["#{Dir.pwd}/public/images/patchwork/*.jpg"].sample.sub("#{Dir.pwd}/public",'')
end

get '/:seriesname/:nym/flyers.pdf' do |seriesname, nym|
	series = Series.first(:name => seriesname)
	if request.cookies[series.cookie_name] == series.passphrase or request.cookies[series.cookie_name] == SECRET_PASSWORD
		imagepath = File.join(Dir.pwd, 'images', seriesname, nym, "image.#{series.imfmt}")
		im = Magick::Image.read(imagepath).first
		im.resize!(400.0/im.columns.to_f)

    nim = Magick::Image.new(500, 1000) { self.background_color = 'white' }
		nim.composite!(im, 50, 50, Magick::CopyCompositeOp)

    content_type :pdf
    nim.to_blob { self.format = 'pdf' }
  else
  	redirect '/images/error.jpg'
	end
end

#get '/robots.txt' do
#	content_type "text/text"
#	expires(60*60*24*365)
#	ROBOTICS
#end

get '/favicon.ico' do
	content_type "image/ico"
	expires(60*60*24*365)
	File.open(File.join(Dir.pwd, 'images', 'favicon.ico')) { |f| f.read }
end

get '/comments' do
  @passphrase = request.cookies[HOOPHIC_COMMENTS]
	@comments = Comment.all.sort
	erb :cedit
end

post '/comments' do
  unless params[:passphrase].blank?
   	passphrase = params[:passphrase]
    response.set_cookie(HOOPHIC_COMMENTS, :value => passphrase, :expires => Time.new + 7*24*60*60)
  end

	Comment.all.each do |comment|
		comment.destroy if params['removals'][comment.id.to_s]
	end

	redirect '/comments'
end

get '/:series/editim/:nym.:format' do |seriesname, nym, format|
	locaterealimage(seriesname, nym, 'image', format)
end

get '/:series/editbg/:nym.:format' do |seriesname, nym, format|
	locaterealimage(seriesname, nym, 'bg', format)
end

get '/:series/pdfimage/:nym.:format' do |seriesname, nym, fmt|
  series = Series.first(:name => seriesname)
	if request.cookies[series.cookie_name] == series.passphrase or request.cookies[series.cookie_name] == SECRET_PASSWORD
		imagepath = File.join(Dir.pwd, 'images', seriesname, nym, "image.#{fmt}")
		im = Magick::Image.read(imagepath).first
		cols, rows = im.columns.to_i, im.rows.to_i

    nim = Magick::Image.new(cols, rows) { self.background_color = 'gray50' }.raise.normalize.blur_image(0.0, 6.0)
    im.composite!(nim, 0, 0, Magick::HardLightCompositeOp)

		nim = Magick::Image.new(cols, rows*1.5) { self.background_color = 'white' }
		nim.composite!(im, 0, 0, Magick::CopyCompositeOp)
    nim.composite!(im.wet_floor, 0, rows, Magick::OverCompositeOp)

    nim = nim.distort(Magick::PerspectiveDistortion, [0,0,0,0,0,rows,0,rows,cols,0,cols-PINCH,25,cols,rows*1.5,cols-PINCH,(rows*1.5)-PINCH], true)

    gc = Magick::Draw.new
    gc.fill('white')
    gc.polygon(0,0,cols-(PINCH-1),0,cols-(PINCH-1),25)
    gc.draw(nim)

   	content_type fmt.to_sym
    nim.to_blob { self.format = fmt }
  else
  	redirect '/images/error.jpg'
	end
end

get '/:series/editpdf/:nym.pdf' do |seriesname, nym|
  series = Series.first(:name => seriesname)
  halt 403, "Not allowed!\n" unless request.cookies[series.cookie_name] == series.passphrase or request.cookies[series.cookie_name] == SECRET_PASSWORD
  content_type :pdf
	File.open(series.pdfdir + nym + '.pdf', 'r') { |f| f.read }
end

get '/:series/thumb/:nym.:format' do |series, nym, format|
  redirect "/images/#{series}/#{nym}/thumb.#{format}", 301
end

get '/:series/mbg/:nym.:format' do |series, nym, format|
  redirect "/images/#{series}/#{nym}/mbg.#{format}", 301
end

get '/:series/bg/:nym.:format' do |series, nym, format|
  redirect "/images/#{series}/#{nym}/bg.#{format}", 301
end

get '/:series/image/:size/:nym.:format' do |series, size, nym, format|
	size = [50, [500, size.to_i].min].max
  redirect "/images/#{series}/#{nym}/image-#{size}.#{format}", 301
end

get '/:series/image/:nym.:format' do |series, nym, format|
  redirect "/images/#{series}/#{nym}/image.#{format}", 301
end

get '/:series/sysimage/:name.:format' do |series, name, format|
  content_type 'image/' + (format == 'png' ? 'png' : 'jpeg')
	expires(60*60*24*365)
  imagepath = File.join(Dir.pwd, 'images', series, "_#{name}.#{format}")
	File.open(imagepath, 'r') { |f| f.read }
end

get '/sysimage/:name.jpg' do |name|
  content_type 'image/jpg'
  imagepath = File.join(Dir.pwd, 'images', "_#{name}.jpg")
	File.open(imagepath, 'r') { |f| f.read }
end

get %r{/(.+)/comment/hide/(\d+)/(\d+)(/m)?} do |series, story_id, id, mob|
  comment = Comment.get(id.to_i)
  comment.hidden = 1 if comment.hidden == 0
  comment.save!
	redirect "/#{series}/story/#{story_id}#{mob}"
end

post %r{/(.+)/comment/add(/m)?} do |series, mob|
  @series = Series.first(:name => series)
	id = params[:comment_story_id].to_i
	if params[:comment_submit] != "Cancel"
	  if story = @series.stories.get(id)
      params[:comment][:when] = DateTime.now
      story.comments.create(params[:comment])
	  end
	end
	redirect "/#{series}/story/#{id}#{mob}"
end

get '/:series/doc/:nym.pdf' do |series, nym|
  @series = Series.first(:name => series)
	story = @series.find_story(nym, true)
	unless /\.php/.match(request.path)
  	referrer = request.referrer.blank? ? 'unknown' : request.referrer
		story.accesses << Access.create(:referrer => referrer, :creation => Time.now, :alien => request.cookies[@series.cookie_name].nil?)
		story.save
	end
	if story and story.pdf_available?
  	story.downloads += 1
  	story.save!
    content_type 'application/pdf'
		attachment "#{story.acronym}.pdf"
    File.open(story.pdf, 'r') { |f| f.read }
  else
    redirect "/#{series}/story/#{nym}"
  end
end

get %r{^/(.+)/story/(\w+)(/m)?$} do |series, nym, mob|
  redirect "/#{series}/story/#{nym}/m" unless mob or !is_mobile_device?(request.user_agent)
  @series = Series.first(:name => series)
  @stories = @series.sorted_leads
	@highlight = @nextup = @series.find_story(nym)
  erb_stories mob
end

get %r{^/(.+)/teststory/(\w+)?$} do |series, nym|
  @series = Series.first(:name => series)
  @stories = @series.sorted_leads
	@highlight = @series.find_story(nym)
  erb :test
end

get '/:series/list/:story' do |series, nym|
	@series = Series.first(:name => series)
	if request.cookies[@series.cookie_name] == @series.passphrase or request.cookies[@series.cookie_name] == SECRET_PASSWORD
		@story = @series.find_story(nym)
		erb :list
	else
		redirect "/#{series}"
	end
end

get '/:series/edit' do |series|
  @series = Series.first(:name => series)
  @keepopen = params[:keepopen]
	@stories = @series.stories
  @passphrase = request.cookies[@series.cookie_name]
	response.set_cookie(@series.cookie_name, :expires => Time.new - 100) unless @passphrase == @series.passphrase or @passphrase == SECRET_PASSWORD
	erb :edit
end

post '/:series/edit' do |series|
  @series = Series.first(:name => series)
  @keepopen = params[:keepopen]

  if params[:passphrase].blank?
    @passphrase = request.cookies[@series.cookie_name]
  else
    @passphrase = params[:passphrase]
    response.set_cookie(@series.cookie_name, :value => @passphrase, :expires => Time.new + 7*24*60*60)
  end

  @series.apply_changes(params['seriesupdate']) if params['seriesupdate']

	if params['storydata']

		@stories = Array.new
		@series.sorted.each do |story|
		  if params['storydata'][story.id.to_s][:remove]
		    story.destroy!
	    else
	      story.apply_changes(params['storydata'][story.id.to_s])
	      @stories << story
	    end
	  end

	  if params['storydata']['new']['name'] != ''
	    story = Story.create(:series => @series)
	    story.apply_changes(params['storydata']['new'])
	    story.save!
	    @series.stories << story
	    @series.save!
	    @stories << story
	  end
	else
		@stories = @series.stories
	end

	unless @keepopen.blank?
		redirect "/#{series}/edit?keepopen=#{@keepopen}"
	else
		redirect "/#{series}/edit"
	end
end

get %r(^/(m)?$) do |mob|
   @series = [
      Series.first(:name => 'ccps'),
      Series.first(:name => 'eote'),
      Series.first(:name => 'lotl'),
      Series.first(:name => 'dotd'),
      Series.first(:name => 'motm'),
      Series.first(:name => 'dwns'),
      Series.first(:name => '12soc')
   ]
	 erb (mob.blank? ? :everything : :meverything)
end

get %r{^/([^\/]+)(/m)?$} do |series, mob|
  redirect "/#{series}/m" unless mob or !is_mobile_device?(request.user_agent)
  @series = Series.first(:name => series)
  @stories = @series.sorted_leads
  @nextup = @series.nextup
  erb_stories mob
end


# require 'common'
# Series.first(:name => "ccps").stories.each do |s|
# File.rename(File.join(Dir.pwd, "public", 'images', "ccps", "#{s.imgfile}.jpg"), File.join(Dir.pwd, "public", 'images', "ccps", "#{s.acronym}.jpg")) if File.exist?(File.join(Dir.pwd, "public", 'images', "ccps", "#{s.imgfile}.jpg"))
# File.rename(File.join(Dir.pwd, "public", 'images', "ccps", "bg", "#{s.bgfile}.jpg"), File.join(Dir.pwd, "public", 'images', "ccps", "bg", "#{s.acronym}.jpg")) if File.exist?(File.join(Dir.pwd, "public", 'images', "ccps", "bg", "#{s.bgfile}.jpg"))
# File.rename(File.join(Dir.pwd, "docs", "ccps", "#{s.pdffile}.pdf"), File.join(Dir.pwd, "docs", "ccps", "#{s.acronym}.pdf")) if
# File.exist?(File.join(Dir.pwd, "docs", "ccps", "#{s.pdffile}.pdf"))
# end
