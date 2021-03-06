rack-i8n_best_langs: guess best language for content served over Rack
=====================================================================

rack-i18n_best_langs is a Rack middleware component that takes care of
understanding what are the best languages for a site visitor.

If you manage a site that has content many languages and also localized URLs,
you will find `rack-i18n_best_langs` very useful, especially when used in
conjunction with [`rack-i18n_routes`](https://github.com/gioele/rack-i18n_routes).

Differently from other similar Rack middleware components,
`rack-i18n_best_langs` returns a list of languages in order of guessed
importance, not a single language. Also, it does not require Rails or
the `i18n` gem.


Features
--------

Language discovery is done using three clues:

* the presences of language tags in paths (e.g. `/service/warranty/ita`),
* the content of the HTTP `Accept-Language` header,
* the content of the `rack.i18n_best_langs` cookie when set.

All these clues are taken into account and evaluated against the list
of languages available and their preferred order. It is possible to configure
which of these clues is the most important.

An additional clue is available when `AliasMapping` (part of
[rack-i18n_routes](http://rubydoc.info/gems/rack-i18n_routes)) is used as the
mapping function: the language in which the path is written. For example,
`/articles/the-victory` implies that the user has a preferences for English,
`/artículos/la-victoria` for Spanish and `/articles/la-victoire` for French.


How it works
------------

Each request is analysed in search for possible clues that can expose what
are the best languages to use in the content served in response. Each clue
contributes part of the final score of each language; the score is amplified
by the weight associated to the clue.

For example, if a person requests the URL `/article/vittoria/ita` from
a browser in a German internet point (thus sending `Accept-Language: de-DE`),
their request would lead to the following scores:

* `ita`: 315 = 0 (not in header) + 15 (partially language of URL) + 300 (path
   ends in `/ita`);
* `eng`: 15 = 0 (not in header) + 15 (partially language of URL) + 0 (path
   does not end in `/eng`);
* `ger`: 3 = 3 (in header) + 0 (not language of URL) + 0 (path does not end
   in `/ger`).

The downstream application will find the guessed languages in the
`rack.i18n_best_langs` env variable, in order of importance.

    env['rack.i18n_best_langs'] # => [ 'ita', 'eng', 'ger' ]

At this point, it is up to the application to choose what to do, either change
the locale using the `i18n` gem, set up its own locale management system or
just keep track of this information.


Examples
--------

`rack-i18n_best_langs` works like any other Rack middleware component.

    # in your server.ru rackup file
    require 'rack/i18n_best_langs'

    FAVORITE_LANGUAGES = %w(eng spa deu fra)

    use Rack::I18nBestLangs, FAVORITE_LANGUAGES
    run MyApp

In your application you will find the list of languages that should be used to
serve the content, arranged from the most favorite to the least in the
`rack.i18n_best_langs` Rack variable. It is then up to downstream application
to use this information in the best way.

### See the guessed languages

This small application

    # in your server.ru rackup file
    require 'rack/i18n_best_langs'

    FAVORITE_LANGUAGES = %w(eng spa deu)

    use Rack::I18nBestLangs, FAVORITE_LANGUAGES

    app = Proc.new do |env|
        langs = env['rack.i18n_best_langs']
        [200, {"Content-Type" => "text/plain"}, [langs.inspect] ]
    end

    run app

will produce the following results for these URLs.

    # /foo =>
    #    [#<LocaleCode 'eng'>, #<LocaleCode 'spa'>, #<LocaleCode 'deu'>]

    # /foo/spa =>
    #    [#<LocaleCode 'spa'>, #<LocaleCode 'eng'>, #<LocaleCode 'deu'>]

    # /foo (with Accept-Language = it-IT, es-ES, fr-FR) =>
    #    [#<LocaleCode 'spa'>, #<LocaleCode 'eng'>, #<LocaleCode 'deu'>]

    # /foo/deu (with Accept-Language = it-IT, es-ES) =>
    #    [#<LocaleCode 'deu'>, #<LocaleCode 'spa'>, #<LocaleCode 'eng'>]

    # /foo (with cookie set to 'deu') =>
    #    [#<LocaleCode 'deu'>, #<LocaleCode 'eng'>, #<LocaleCode 'spa'>]

    # /foo/spa (with cookie set to 'deu') =>
    #    [#<LocaleCode 'deu'>, #<LocaleCode 'spa'>, #<LocaleCode 'eng'>]


### Changing the clues' weights

You can tune the weights of the clues to set which clue is the most important.

The default order of importance and weights are

* language set in cookie (`:cookie`): 3
* language present in tag (`:path`): 2
* language is in `Accept-Language` header (`:header`): 1

You can change these weight with the `:weights` option.

    FAVORITE_LANGUAGES = %w(eng spa deu)
    WEIGHTS = { :path => 3, :header => 2, :cookie = 1 }

    use Rack::I18nBestLangs, FAVORITE_LANGUAGES, :weights => WEIGHTS

To disable the use of any of the clues, set its weight to zero.

### Using `AliasMapping`

If you want to use the content of the URI path as an additional clue to guess
the best languages, use an `AliasMapping` function as path mapping function.

    # in your server.ru rackup file
    require 'rack/i18n_best_langs'
    require 'rack/i18n_routes/alias_mapping'

    FAVORITE_LANGUAGES = %w(eng spa deu fra)

    aliases = {
        'articles' => {
            'fra' => 'articles',
            'spa' => ['artículos', 'articulos']

            :children => {
                'the-victory' => {
                    'fra' => 'la-victoire',
                    'spa' => 'la-victoria'
                }
                'the-block' => {
                    'fra' => 'le-bloc',
                    'spa' => 'el-bloque'
                }
            }
        }
    }
    MAPPING = Rack::I18nRoutes::AliasMapping.new(paths, :default => 'eng')

    use Rack::I18nBestLangs, FAVORITE_LANGUAGES, :path_mapping_fn => MAPPING
    run MyApp


Requirements
------------

No requirements outside Ruby >= 1.8.7 and Rack.


Install
-------

    gem install rack-i18n_best_langs


Author
------

* Gioele Barabucci <http://svario.it/gioele> (initial author)


Development
-----------

Code
: <https://github.com/gioele/rack-i18n_best_langs>

Report issues
: <https://github.com/gioele/rack-i18n_best_langs/issues>

Documentation
: <http://rubydoc.info/gems/rack-i18n_best_langs>


License
-------

This is free software released into the public domain (CC0 license).

See the `COPYING` file or <http://creativecommons.org/publicdomain/zero/1.0/>
for more details.
