class Access
  include DataMapper::Resource

  property :id,         Serial
	property :referrer,		String, :length => 200, :required => true
  property :creation,		DateTime
  property :alien,			Boolean, :default => true

	belongs_to :story

	def <=>(other)
		other.creation <=> self.creation
	end

end
