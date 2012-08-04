# This is free software released into the public domain (CC0 license).
#
# See the `COPYING` file or <http://creativecommons.org/publicdomain/zero/1.0/>
# for more details.


require File.join(File.dirname(__FILE__), 'spec_helper')

describe Rack::I18nBestLangs do
	AVAIL_LANGUAGES = ['ita', 'fra', 'eng', 'ara']

	def app(*opts)
		builder = Rack::Builder.new do
			use Rack::Lint
			use Rack::I18nBestLangs, *opts
			use Rack::Lint

			run lambda { |env| [200, {"Content-Type" => "text/plain"}, [""]] }
		end

		return builder.to_app
	end

	def request_with(path, env_opts = {}, *i18n_opts)
		if i18n_opts.empty?
			extra_opts = {}
			extra_opts[:path_lookup_fn] = Proc.new { |orig_path| orig_path }

			i18n_opts << AVAIL_LANGUAGES # known_languages
			i18n_opts << extra_opts
		end

		session = Rack::Test::Session.new(Rack::MockSession.new(app(*i18n_opts)))
	        session.request(path, env_opts)

        	return session.last_request
	end

	def http_langs(*langs)
		{ 'HTTP_ACCEPT_LANGUAGE' => langs.flatten.join(', ') }
	end

	def cookie_langs(*langs)
		{ 'HTTP_COOKIE' => Rack::I18nBestLangs::RACK_VARIABLE + "=" + langs.flatten.join(',') }
	end

	context "with no external information" do
		it "suggests exactly the list of languages" do
			env = request_with('/').env
			languages = env[Rack::I18nBestLangs::RACK_VARIABLE]

			languages.should be_an Array
			languages.should == AVAIL_LANGUAGES
		end

		it "is not confused by paths that look like languages" do
			env = request_with('/francesca').env
			languages = env[Rack::I18nBestLangs::RACK_VARIABLE]

			languages.should == AVAIL_LANGUAGES
		end
	end

	context "with language in path" do
		it "places that language as best language when available" do
			env = request_with('/fra/').env
			languages = env[Rack::I18nBestLangs::RACK_VARIABLE]

			languages.first.should eq('fra')
			languages.should include(*AVAIL_LANGUAGES)
		end

		it "ignores that language when not available" do
			env = request_with('/lat/').env
			languages = env[Rack::I18nBestLangs::RACK_VARIABLE]

			languages.should == AVAIL_LANGUAGES
		end

		it "selects the first path component" do
			env = request_with('http://italia.example.org/foo/fra').env
			languages = env[Rack::I18nBestLangs::RACK_VARIABLE]

			languages.first.should eq('fra')
			languages.should include(*AVAIL_LANGUAGES)
		end

		it "removes the language from the path" do
			env = request_with('/foo/fra').env
			languages = env[Rack::I18nBestLangs::RACK_VARIABLE]

			languages.first.should eq('fra')
			env['PATH_INFO'].should eq('/foo')
		end
	end

	context "with language in headers" do
		it "places that language as best language when available" do
			env = request_with('/hello', http_langs('fr-FR')).env
			languages = env[Rack::I18nBestLangs::RACK_VARIABLE]

			languages.first.should == 'fra'
		end
	end

	context "with language in cookie" do
		it "places that language as best language when available" do
			env = request_with('/hello', cookie_langs('eng')).env
			languages = env[Rack::I18nBestLangs::RACK_VARIABLE]

			languages.first.should == 'eng'
		end
	end
end

