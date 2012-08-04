# This is free software released into the public domain (CC0 license).
#
# See the `COPYING` file or <http://creativecommons.org/publicdomain/zero/1.0/>
# for more details.


require 'rack/language_tag.rb'

module Rack

class I18nBestLangs
	RACK_VARIABLE = 'rack.i18n-best-langs'

	# Create a new I18nBestLangs middleware component.
	#
	# @param [[String]] avail_languages
	#
	# @param [Hash] opts
	# @option opts [Hash{Symbol => Integer}] :weights Weights for clues
	#                                                 (the higher, the most
	#                                                 important): `:header`,
	#                                                 `:path`, `:cookie`.
	# @option opts [Proc] :path_lookup_fn A function that maps localized
	#                                     URI paths into normalized paths,
	#                                     should be a Rack::I18nRoutes::AliasMapping.

	def initialize(app, avail_languages, opts = {})
		@app = app

		score_base = avail_languages.length

		weights = opts[:weights] || {}
		weight_header = weights[:header] || 1
		weight_path   = weights[:path]   || 2
		weight_cookie = weights[:cookie] || 3

		@score_for_header = score_base * (10 ** weight_header)
		@score_for_path   = score_base * (10 ** weight_path)
		@score_for_cookie = score_base * (10 ** weight_cookie)

		@avail_languages = {}
		avail_languages.each_with_index do |lang, i|
			code = LanguageTag.new(lang).freeze
			score = score_base - i

			@avail_languages[code] = score
		end

		@language_path_regex = regex_for_languages_in_path

		@path_lookup = opts[:path_lookup_fn] || Proc.new { |path| path }
	end

	def call(env)
		lang_info = find_best_languages(env)
		env[I18nBestLangs::RACK_VARIABLE] = lang_info[:languages]
		env['PATH_INFO'] = lang_info[:path_info]

		return @app.call(env)
	end

	def find_best_languages(env)
		path = env['PATH_INFO']
		accept_language_header = extract_language_header(env)
		cookies = extract_language_cookie(env)

		clean_path_info = remove_language_from_path(path)

		langs = @avail_languages.dup
		add_score_for_path(path, langs)
		add_score_for_accept_language_header(accept_language_header, langs)
		add_score_for_cookie(cookies, langs)

		sorted_langs = langs.to_a.sort_by { |lang_info| -(lang_info[1]) }.map(&:first)

		info = {
			:languages => sorted_langs,
			:path_info => clean_path_info,
		}

		return info
	end

	def extract_language_header(env)
		header = env['HTTP_ACCEPT_LANGUAGE']

		if (header =~ HEADER_FORMAT)
			return header
		else
			# FIXME: env.warn
			return ""
		end
	end

	def extract_language_cookie(env)
		return Rack::Request.new(env).cookies[I18nBestLangs::RACK_VARIABLE]
	end

	def remove_language_from_path(path)
		return path.sub(@language_path_regex, '')
	end

	def add_score_for_path(path, langs)
		path_match = path.match(@language_path_regex)

		path_include_language = !path_match.nil?
		if !path_include_language
			return
		end

		lang_code = LanguageTag.new(path_match[1])
		langs[lang_code] += @score_for_path
	end

	def add_score_for_accept_language_header(accept_language_header, langs)
		if accept_language_header.nil? || !valid_language_header(accept_language_header)
			return
		end

		header_langs = languages_in_accept_language(accept_language_header)

		header_langs.each do |lang, q|
			if !langs.include?(lang)
				next
			end

			langs[lang] += @score_for_header * q
		end
	end

	def add_score_for_cookie(cookie, langs)
		if cookie.nil?
			return
		end

		cookie_langs = cookie.split(',').map { |tag| LanguageTag.parse(tag) }

		cookie_langs.reverse.each_with_index do |lang, idx|
			if !langs.include?(lang)
				next
			end

			importance = idx + 1
			langs[lang] += @score_for_cookie * importance
		end
	end

	def valid_language_header(accept_language_header)
		return true # FIXME: check with regex
	end

	def languages_in_accept_language(accept_language_header)
		raw_langs = accept_language_header.split(',')

		langs = raw_langs.map { |l| l.sub('q=', '')}.
		                      map { |l| l.split(';') }

		langs.each_with_index do |l, i|
			l[0] = LanguageTag.parse(l[0])
			l[1] = (l[1] || 1).to_f

			sorting_epsilon = (langs.size - i).to_f / 100
			l[1] += sorting_epsilon # keep the original order when sorting
		end

		return langs
	end

	def regex_for_languages_in_path
		all_languages = @avail_languages.keys.map(&:alpha3)

		preamble = "/"
		body = "(" + all_languages.join("|") + ")"
		trail = "/?$"

		return Regexp.new(preamble + body + trail)
	end


	def self.accept_language_format
		lang = '[-_a-zA-Z]+'
		qvalue = '(; ?q=[01]+(\.[0-9]{1,3})?)'

		return Regexp.new("\\A#{lang}#{qvalue}?(, ?#{lang}#{qvalue}?)*\\Z")
	end

	HEADER_FORMAT = self.accept_language_format
end

end
