
Series.all.each do |ser|
  ser.stories.all.each do |a|
    dir = "#{Dir.pwd}/images/#{ser.name}/#{a.acronym}"
    FileUtils.mv(dir + ".#{ser.imfmt}", dir + "/image.#{ser.imfmt}") if File.exist?(dir + ".#{ser.imfmt}")
  end
end