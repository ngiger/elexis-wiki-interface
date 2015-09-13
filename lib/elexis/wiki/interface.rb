#encoding: utf-8

require 'eclipse/plugin'
require 'media_wiki'
require 'mediawiki_api'
require 'fileutils'
require 'open-uri'
require 'time'
require 'yaml'

module Elexis
  module Wiki
    ImagePrefix  = /Datei:|Image:/i
    ImagePattern = /(\[Datei:|\[Image:)([\w\.\:\/]*)/i
    TestPattern = /[\._]test[s]*$/i

    class Interface
      attr_reader :user, :password, :wiki_url, :mw_gw, :mw_api

      private
        def load_config_file(wiki_url)
          possibleCfgs = ['/etc/elexis-wiki-interface/config.yml', File.join(Dir.pwd, 'config.yml'), ]
          possibleCfgs.each{ |cfg| @config_yml = cfg; break if File.exists?(cfg) }
          raise "need a config file #{possibleCfgs.join(' or ')} for wiki with user/password" unless File.exists?(@config_yml)
          yaml = YAML.load_file(@config_yml)
          @wiki_url = wiki_url
          @wiki_url ||= defined?(RSpec) ? yaml['test_wiki'] : yaml['wiki']
          @user = yaml['user']
          @password = yaml['password']
          puts "MediWiki #{@wiki_url} user #{@user} with password #{@password}" if $VERBOSE
          wiki_url
        end

      public

        def initialize(wiki_url=nil)
          load_config_file(wiki_url)
          @mw_gw = MediaWiki::Gateway.new(@wiki_url)
          @mw_gw.login(user, password)
          @mw_api = MediawikiApi::Client.new @wiki_url
          res = @mw_api.log_in(user, password)
          $ws_errors = []
        end

        def images(page)
          @mw_gw.images(page)
        end

        def users
          @mw_gw.users
        end

        def contributions(username)
          @mw_gw.contributions(username)
        end

        def get(page)
          @mw_gw.get(page)
        end

        def create(page, content, options = {})
          @mw_api.create_page(page, content)
        end

        def edit(page, text)
          @mw_api.edit({:title => page, :text => text})
        end

        def delete(page, reason='')
          @mw_api.delete_page(page, reason)
        end

        def upload_image(filename, path, comment='', options = {})
          # fails with mediawiki 1.19 because of missing @tokens
          res = @mw_api.upload_image(filename, path, comment, options)
        end
        alias_method :upload, :upload_image

      def Interface.return_canonical_image_name(pagename, filename)
        pagename = pagename.sub('.feature.feature.group', '')
        short = File.basename(filename.downcase.sub(ImagePrefix, ''))
        short = short.split(':')[-1]
        /[:\/]/.match(filename) ? pagename + '/' + short : short
      end

      def Interface.remove_image_ignoring_case(filename)
        files = Dir.glob(filename, File::FNM_CASEFOLD)
        return if files.size == 1
        files.each{
          |file|
            next if File.basename(file).eql?(File.basename(filename))
            cmd = "git rm -f #{file}"
            res = system(cmd)
        }
      end

      def Interface.fix_image_locations(filename, pagename)
        return unless File.exists?(filename)
        pagename = pagename.sub('.feature.feature.group', '')
        lines = IO.readlines(filename)
        dirName = File.dirname(filename)
        newLines = ''
        showDetails =  $VERBOSE
        if /icpc.mediawiki/i.match(filename)
          showDetails = true
        end
        lines.each{
          |line|
          unless m =ImagePattern.match(line)
            newLines += line
          else
            new_name = Interface.return_canonical_image_name(pagename, m[2])
            unless new_name.eql?(File.basename(new_name))
              FileUtils.ln_s('.', File.dirname(new_name), :verbose => true) unless File.exists?(File.dirname(new_name))
            end
            simpleName = File.join(dirName, File.basename(new_name))
            if files = Dir.glob(simpleName, File::FNM_CASEFOLD) and files.size >= 1
              new_line = line.sub(m[2], new_name)
              newLines += new_line
              Interface.remove_image_ignoring_case(simpleName)
            else
              next if defined?(RSpec)
              msg =  "Could not find image for #{m[0]} searched for #{simpleName} in #{Dir.pwd}. files are #{files}"
              puts msg
              $ws_errors << msg
              newLines += line.sub(ImagePattern, "#{m[1]}#{m[2].sub(':', '_')}")
            end
          end
        }
        File.open(filename, "w") {|f| f.write newLines.gsub(/\[\[Datei:|\[\[Image:/i, '[[File:')}
      end
    end
  end
end
