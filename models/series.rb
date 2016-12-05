class Series
  include StoryHelper
  include DataMapper::Resource

  property :id,           Serial
  property :name,         String
  property :title,        String
  property :passphrase, 	String, :default => 'grunties'
  property :description,  Text
  property :startdate,    DateTime
  property :imfmt,      	String, :default => 'png'
  property :imwidth,			Integer, :default => 200
  property :published,		Boolean, :default => false
  property :bgw,					Integer, :default => 0
  property :bgh,					Integer, :default => 0
  property :css,					Text
  property :bgfmt,        String, :default => 'jpg'

  has n, :stories

  def create_chapter_groupings
    chaps = []
    sorted.each_with_index do |s, i|
      chaps << i
      s.chapters = chaps
      chaps = [] unless s.connected?
    end
  end

	def findBgDimensions
	  imagepath = "#{Dir.pwd}/public/images/#{self.name}/sysimage/bg.jpg"
	  im = Magick::Image.read(imagepath).first
		self.bgw = im.columns.to_i
		self.bgh = im.rows.to_i
		self.save!
	end

	def bgwidth
		findBgDimensions if self.bgw == 0
		bgw
	end

	def bgheight
		findBgDimensions if self.bgh == 0
		bgh
	end

  def image_path(dest)
    s = image_path_fetch(dest)
    File.exists?(s) ? s : "#{Dir.pwd}/images/bg.jpg"
  end

	def <=>(other)
		self.startdate <=> other.startdate
	end

	def others
		@others ||= Series.all(:published => true, :id.not => self.id).sort
	end

  def sorted
    @sorted ||= stories.sort
	end

	def sorted_leads
	  @sorted_leads ||= sorted.reject { |s| s.connected? }
	end

	def freshen
		@sorted = nil
	end

	def nextup
		unless @nu
			now = DateTime.now
		  @nu = sorted_leads.last
		  sorted_leads.reverse.each do |s|
		    @nu = s if s.date > now
		  end
		end
		@nu
	end

	def find_story(nym, exact = false, ignore = nil)
    id = Integer(nym) rescue false
	  sorted.each_with_index do |story, idx|
	    if story != ignore and (story.id == id or story.acronym == nym)
	      return sorted[idx] if exact
	      idx = idx - 1 while idx > 0 and sorted[idx].connected?
	      return sorted[idx]
	    end
    end
    nil
	end

	def apply_changes(params)
	  params['description'] = params['description'].gsub("\n", "|") if params['description']

    [['image', self.imfmt], ['logo', 'png'], ['mlogo', 'png'], ['bg', self.bgfmt]].each do |imdata|
      dimensions = uploadimg(locate_image(imdata[0], imdata[1]), imdata[0], params, imdata[1])
      if dimensions and imdata[0] == 'bg'
        self.bgw, self.bgh = dimensions[0], dimensions[1]
        self.save
      end
    end

	  self.update(params)
  end

  def imgdir
    @imgdir ||= File.join(Dir.pwd, 'images', self.name) + '/'
  end

  def pdfdir
    @pdfdir ||= File.join(Dir.pwd, 'docs', self.name) + '/'
  end

  def locate_image(imtype = 'image', format = self.imfmt)
    imgdir + '/sysimage/' + imtype + '.' + format
  end

  def has_default_story_image?
  	has_file?(locate_image)
  end

  def has_background?
  	has_file?(locate_image('bg', self.bgfmt))
  end

  def has_logo?
  	has_file?(locate_image('logo', 'png'))
  end

  def has_mlogo?
  	has_file?(locate_image('mlogo', 'png'))
  end

  def pdate
  	startdate.strftime(DATEFORMAT)
	end

	def pday
		startdate.strftime('%a')
	end

	def cookie_name
		@cn ||= 'hoophic_' + name
	end

end
