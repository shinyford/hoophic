require 'rubygems'
require 'dm-core'
require 'dm-validations'
require 'dm-migrations'
require 'dm-timestamps'

RESOURCEBASE = ''
IMAGEBASE = '/images'
COVERWIDTH = 200
STORIESMAXOFFSET = 500
COMMENTINPUTMESSAGE = 'Note that anything submitted here is subject to an honour system, and you are asked to be honest and respectful when leaving your name and comment. Any comment deemed to be offensive by the moderators may be deleted.'
DATEFORMAT = '%a %-d %b %Y'
TIMEFORMAT = '%a %d/%m/%Y %H:%M:%S'
FAVICONV=5

# fix required for bug with DataMapper 1.1.0 and Ruby 1.8.6
module Enumerable
  unless instance_methods.include?("first")
    def first(num = nil)
      if num == nil
        holder = nil
        catch(:got_element) do
          each do |e|
            holder = e
            throw(:got_element)
          end
        end
        holder
      else
        holder = []
        catch(:got_elements) do
          each do |e|
            holder << e
            throw(:got_element) if num == 0
            num -= 1
          end
        end
        holder
      end
    end
  end
end

def nil.blank?
	true
end

class String
	def blank?
		self == ''
	end
end

class Hash
  def blank?
    false
  end
end

module StoryHelper

	def has_file?(file)
		[File.mtime(file), File.size?(file)] if File.exist?(file)
	end

  def image_path_fetch(dest)
    if dest.match(/\/([^\/\.]+)\.([^\/\.]+)$/)
    	imtypename = $1
    	fmt = $2
      case imtypename
      when 'mbg'
        imtype, width = 'bg', 640
      when 'bg'
        imtype, width = 'bg', 0
      when 'thumb'
        imtype, width = 'image', 111
      when 'pdfimage'
        imtype, width = 'image', 0
      else
        imtype, width = 'image', (imtypename.match(/^image-(.*)$/) ? $1.to_i : 0)
      end
puts "Looking for #{imtype} #{fmt} width #{width}"
      s = locate_image(imtype, fmt)
      if s and File.exist?(s)
      	d = "#{Dir.pwd}/public#{dest}"      	
        unless File.exist?(d) and File.mtime(d) > File.mtime(s)
          FileUtils.mkdir_p(File.dirname(d))
          if width > 0
            im = Magick::Image.read(s).first
            im.scale!(Rational(width, im.columns.to_i))
            img = im.to_blob { self.format = fmt }
            File.open(d, 'w') { |f| f.write(img) }
          else
puts "Linking #{s} to #{d}"
            File.symlink(s, d)
          end
        end
        dest
      else
      	nil
      end
    end
  end
end

DataMapper.setup(:default, "sqlite3://#{Dir.pwd}/db_hoophic.sqlite3")
require 'models/series'
require 'models/story'
require 'models/comment'
require 'models/access'
DataMapper.auto_upgrade!

Series.all.each do |a|
  d = "#{Dir.pwd}/public/images/#{a.name}"
  s = "#{Dir.pwd}/images/#{a.name}/sysimage"
  FileUtils.mkdir_p(d)
  d += '/sysimage'
  File.symlink(s, d) if File.exist?(s) and not File.exist?(d)
end
