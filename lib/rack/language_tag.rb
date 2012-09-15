# This is free software released into the public domain (CC0 license).
#
# See the `COPYING` file or <http://creativecommons.org/publicdomain/zero/1.0/>
# for more details.


# BCP 47

class LanguageTag
	VERSION = "5646.0.1"

	A3_TO_A2 = {
		'ara' => 'ar',
		'deu' => 'de',
		'eng' => 'en',
		'fra' => 'fr',
		'ita' => 'it',
	}

#	class UnparseableLanguageTag < Exception; end
#	class UnknownLanguageTagError < Exception; end

	def self.parse(raw_code)
		iso_code = raw_code.split('-').flatten.first

		if iso_code.nil?
			return nil
			# raise UnparseableLanguageTag, "Unparseable language tag" # FIXME
		end

		if !(A3_TO_A2.keys + A3_TO_A2.values).include?(iso_code)
			return nil
			# raise UnknownLanguageTagError, "Unknown language tag #{iso_code}" # FIXME
		end

		return LanguageTag.new(iso_code)
	end

	def initialize(iso_code, extlang = nil, script = nil, region = nil, variant = [], extension = [], privateuse = nil)
		case iso_code.length
		when 3
			@alpha3 = iso_code
		when 2
			@alpha2 = iso_code
		end
	end

	def alpha2
		@alpha2 ||= a3_to_a2(@alpha3)
	end

	def alpha3
		@alpha3 ||= a2_to_a3(@alpha2)
	end

	def a3_to_a2(alpha3)
		return A3_TO_A2[alpha3]
	end

	def a2_to_a3(alpha2)
		return A3_TO_A2.invert[alpha2]
	end

	def complete
		alpha3
	end

	def ==(other_code)
		return self.complete == LanguageTag.new(other_code).complete
	end

	def hash
		self.complete.hash
	end

	def eql?(other)
		if self.equal?(other)
			return true
		elsif self.class != other.class
			return false
		end

		return self.alpha3 == other.alpha3
	end

	def inspect
		return "#<LocaleCode '#{complete}'>"
	end
end
