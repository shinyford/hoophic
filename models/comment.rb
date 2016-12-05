class Comment
  include DataMapper::Resource

  property :id,         Serial
  property :from,       String
	property :comment,		Text
	property :when,       DateTime
	property :hidden,			Integer, :default => 0

	belongs_to :story

  def <=>(other)
  	puts "Comparing #{self.id} with #{other.id}"
  	r = self.story <=> other.story
  	(r == 0) ? self.when <=> other.when : r
	end

end