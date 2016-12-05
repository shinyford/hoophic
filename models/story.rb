require 'date'
require 'RMagick'

EPOCH = DateTime.new(1970, 1, 1)

class Story
  include StoryHelper
  include DataMapper::Resource

  property :id,           Serial
  property :name,         String,   :length => 200, :default => 'CHANGE THIS'
  property :nym,          String
	property :desc,				  Text,     :default => 'DESCRIPTION'
	property :author, 		  String,	  :default => 'AUTHOR'
  property :downloads,	  Integer,  :default => 0
  property :specificday,  Integer,  :default => 0
  property :ordinal,      Integer,  :required => true, :default => 100
  property :pagecount,		Integer,  :default => 0
  property :bgw,					Integer,  :default => 0
  property :bgh,					Integer,  :default => 0
  property :yfrog,				String,   :length => 200
  property :gb,						String,   :length => 200
  property :os,						String,   :length => 200
  property :connected,    Boolean,  :default => false

  has n, :comments
  has n, :accesses
  belongs_to :series

	def findBgDimensions
	  imagepath = "#{Dir.pwd}/images/#{series.name}/bg/#{nym}.jpg"
	  im = Magick::Image.read(imagepath).first
		self.bgw = im.columns.to_i
		self.bgh = im.rows.to_i
		self.save!
	end

	def bgwidth
		findBgDimensions if self.bgw == 0
		self.bgw
	end

	def bgheight
		findBgDimensions if self.bgh == 0
		self.bgh
	end

	def chapters
    unless @chapters
      @chapters = [self]
      (self.idx+1 .. series.sorted.length-1).each do |i|
        break unless series.sorted[i].connected?
        @chapters << series.sorted[i]
      end
    end
    @chapters
	end

	def has_chapters?
	  chapters.length > 1
	end

	def idx
	  series.sorted.index(self)
	end

  def previous
    i = idx
    i > 0 ? series.sorted[i-1] : nil
  end

	def description
		desc || '' # @description ||= ((desc unless desc == '') || "Coming soon...")
	end

  def auth
    author || ''
  end

  def image_path(dest)
    d = image_path_fetch(dest) if img_available?
    d || dest.sub("/#{series.name}/#{self.acronym}/", "/#{series.name}/sysimage/")
  end

  def absolute_image_path
    @aip ||= "/images/#{series.name}/#{self.acronym}/image.#{series.imfmt}"
  end

	def pdf
		@pdf ||= "#{Dir.pwd}/docs/#{series.name}/#{self.acronym}.pdf"
	end

	def pdf_path
	  @pdf_path ||= (pdf_available? ? "/#{series.name}/doc/#{self.acronym}.pdf" : '')
  end

	def img_available?
		(previous.nil? and date - 3 <= DateTime.now) or (previous and previous.pdf_available?)
		#date - 1 <= DateTime.now
  end

	def pdf_available?
		date <= DateTime.now and has_pdf?
	end

	def background_available?
		((series.nextup and date <= series.nextup.date) or (date <= DateTime.now)) and has_background?
	end

	def date
	  d = series.startdate + ((ordinal * 7) + specificday)
		d -= Rational(1,24) if d.mon > 3 and d.mon < 10 # deal coarsely with daylight-saving
		d
	end

	def heading
		unless @heading
			@heading = "'" + name.to_s + "'"
			@heading += ' by ' + author unless author.blank?
		end
		@heading
	end

	def <=>(other)
		r = self.series <=> other.series
    (r == 0) ? self.date <=> other.date : r
	end

  def acronym
    if nym.blank?
			self.nym = generate_acronym(self.name)
			self.save!
		end
		nym
  end

	def renym(ac = nil)
	  ac = generate_acronym(self.name) if ac.nil?
		if ac != nym
      File.rename(series.imgdir + acronym, series.imgdir + ac) if File.exist?(series.imgdir + acronym)
      File.rename(locate_pdf, series.pdfdir + ac + '.pdf') if File.exist?(locate_pdf)

      impath = File.join(Dir.pwd, 'public', 'images', series.name, acronym)
      FileUtils.rm_r(impath) if File.exist?(impath)

			self.nym = ac
			self.save!
		end
	end

  def generate_acronym(newname)
    ac = (newname || '').delete('^0-9a-zA-Z ').split(' ').map { |x| x.split('').first }.join.downcase.gsub(/^[0-9]+/,'')
    if ac.blank?
      ac = 'story'+self.id.to_s
    else
      if series.find_story(ac, true, self)
        self.save! unless self.id # ensure we have an actual id
        ac += self.id.to_s
      end
    end
    ac
  end

  def apply_changes(params)
    ac = generate_acronym(params['name'])
    unless ac == acronym
      renym(ac)
      params[:nym] = ac
		end

    uploadimg(locate_image, 'image', params, series.imfmt)
    uploadfile(locate_pdf, 'pdf', params)
    if params['background'] then
    	self.bgw, self.bgh = uploadimg(locate_image('bg', series.bgfmt), 'background', params, series.bgfmt)
    end

    self.connected = !params.delete('connected').nil?
    self.save
    self.update(params)
    self.save
  end

  def locate_image(imtype = 'image', format = series.imfmt)
    @imglocations ||= {}
    @imglocations[imtype+format] ||= series.imgdir + acronym + '/' + imtype + '.' + format
  end

  def locate_pdf
    @pdflocation ||= series.pdfdir + acronym + '.pdf'
  end

	def has_image?
		has_file?(locate_image)
	end

	def has_background?
		has_file?(locate_image('bg', series.bgfmt))
	end

	def has_pdf?
		has_file?(locate_pdf)
	end

	def pdate
		(date+Rational(1,2)).strftime(DATEFORMAT)
	end

	def pday
		(date+Rational(1,2)).strftime('%a')
	end

	def last_download_time
		@last_download_time ||= ((accesses && accesses.length > 0 && !accesses.last.creation.nil?) ? accesses.last.creation : EPOCH)
	end

	def downloaded_at
		last_download_time.strftime(TIMEFORMAT) if last_download_time > EPOCH
	end

	def numcomments
		@numcomments ||= comments.length
	end

	def last_comment
		unless @last_comment
			if numcomments > 0
				@last_comment = comments.last.when
			else
				@last_comment = EPOCH
			end
		end
		@last_comment
	end

	def last_comment_date
		last_comment.strftime(TIMEFORMAT) if last_comment > EPOCH
	end

	def editim
	  if has_image?
  		"/#{series.name}/editim/#{acronym}.#{series.imfmt}"
  	else
  	  "/images/#{series.name}/sysimage/image.#{series.imfmt}"
  	end
	end

	def editbg
	  if has_background?
  		"/#{series.name}/editbg/#{acronym}.#{series.imfmt}"
  	else
  	  "/images/#{series.name}/sysimage/bg.#{series.bgfmt}"
  	end
	end

  def editpdf
    "/#{series.name}/editpdf/#{acronym}.pdf"
  end

  def pdfimage
    "/#{series.name}/pdfimage/#{acronym}.#{series.imfmt}"
  end

end
