require 'media_wiki'
require 'fileutils'

module Elexis
  module Wiki
    module Interface
      class Workspace
        attr_reader :info, :mw, :views_missing_documentation, :perspectives_missing_documentation, :plugins_missing_documentation
        def initialize(dir, wiki = 'http://wiki.elexis.info/api.php')
          @config_yml = File.join(Dir.pwd, 'config', 'hosts.yml')
          raise "need a config file #{@config_yml} for wiki with user/password" unless File.exists?(@config_yml)
          yaml = YAML.load_file(@config_yml)
          @user = yaml['user']
          @password = yaml['password']
          @wiki = yaml['wiki']
          puts "MediWiki #{@wiki} user #{@user} with password #{@password}" if $VERBOSE
          @mw = MediaWiki::Gateway.new(@wiki)
          @info =  Eclipse::Workspace.new(dir)
          @info.parse_sub_dirs
          @info.show if $VERBOSE
          @views_missing_documentation        =[]
          @perspectives_missing_documentation =[]
          @plugins_missing_documentation      =[]
        end
        def show_missing(details = false)
          puts "Eclipse-Workspace #{@info.workspace_dir} needs documenting "
          puts "  #{views_missing_documentation.size} views"
          puts "    #{views_missing_documentation.inspect}" if details
          puts "  #{plugins_missing_documentation.size} plugins"
          puts "    #{plugins_missing_documentation.inspect}" if details
          puts "  #{perspectives_missing_documentation.size} perspectives"
          puts "    #{perspectives_missing_documentation.inspect}" if details
        end
        def push
          raise "must define wiki with user and password in #{@config_yml}" unless @user and @password and @wiki
          @mw.login(@user, @password)
          @info.plugins.each{
            |id,plugin|
              to_push = Dir.glob("#{plugin.jar_or_src}/doc/*.mediawiki")
              to_push.each{
                           |file|
                            my_new_content = File.new(file).read
                            to_verify = my_new_content.gsub(/\n+/,"\n").chomp
                            pagename = File.basename(file, '.mediawiki')
                            @mw.create(pagename, my_new_content,{:overwrite => true, :summary => "pushed by #{File.basename(__FILE__)}" })
                            got = @mw.get(pagename).gsub(/\n+/,"\n")
                            success = got == to_verify
                            puts "Failed to upload #{file} to #{pagename}" unless success
                       }
          }
        end

        def pull(commitAndPush = false)
          @info.plugins.each{
            |id, info|
              puts "Pulling for #{id}" if $VERBOSE
              pull_docs_views(info)
              pull_docs_plugins(info)
              pull_docs_perspectives(info)
          }
          saved = Dir.pwd
          Dir.chdir(@info.workspace_dir)
          if commitAndPush
            system("git add -f */doc/*.mediawiki")
            system("git status")
            system("git commit --all -m '#{File.basename(__FILE__)}: Added mediawiki content from #{@wiki}'")
            system("git status")
            system("git log -1")
            system("git push")
          end
          Dir.chdir(saved)
        end

        def perspectiveToPageName(perspective)
          # http://wiki.elexis.info/P_Abrechnungen
          name = 'P_'+ perspective.id.gsub(' ', '')
          puts "perspectiveToPageName for #{perspective.inspect} is '#{name}'" if $VERBOSE
          name
        end
        def viewToPageName(plugin_id, view)
          # für ch.elexis.agenda.views.TagesView (= view.id)
          # http://wiki.elexis.info/ChElexisAgendaViewsTagesview
          # wurde unter http://wiki.elexis.info/Hauptseite ein Link Agenda (= view.name) angelegt.
          # evtl. sollten wir testen, ob dieser Link vorhanden ist
          # http://wiki.elexis.info/ChElexisIcpcViewsEpisodesview
          # Could not fetch                                     ChElexisIcpcCodesview from #<MediaWiki::Gateway:0x00000001e30688>
        # name = File.join(@dataDir, "ch.elexis.notes", "doc", "ChElexisIcpcViewsIcpccodesview.mediawiki")
          x = %(
#<struct Struct::UI_View
 id="ch.elexis.icpc.episodesView",
 category="ch.elexis.icpcCategory",
 translation="Probleme">
viewToPageName for ch.elexis.icpc/ch.elexis.icpc.episodesView is ChElexisIcpcViewsEpisodesview
Could not fetch ChElexisIcpcViewsCodesview from #<MediaWiki::Gateway:0x00000002c9b330>
Workspace /opt/src/elexis-wiki-interface/spec/data/pull with 3 plugins 9/2 views 8/2 preferencePages 2 perspectives
["/opt/src/elexis-wiki-interface/spec/data/pull/ch.elexis.notes/doc/Ch.elexis.notes.mediawiki",
 "/opt/src/elexis-wiki-interface/spec/data/pull/ch.elexis.agenda/doc/Ch.elexis.agenda.mediawiki",
 "/opt/src/elexis-wiki-interface/spec/data/pull/ch.elexis.agenda/doc/ChElexisAgendaViewsTagesview.mediawiki",
 "/opt/src/elexis-wiki-interface/spec/data/pull/ch.elexis.icpc/doc/ChElexisIcpcViewsEpisodesview.mediawiki",
 "/opt/src/elexis-wiki-interface/spec/data/pull/ch.elexis.icpc/doc/ChElexisIcpcViewsEncounterview.mediawiki",
 "/opt/src/elexis-wiki-interface/spec/data/pull/ch.elexis.icpc/doc/Ch.elexis.icpc.mediawiki",
 "/opt/src/elexis-wiki-interface/spec/data/pull/ch.elexis.icpc/doc/P_ICPC.mediawiki"]
"/opt/src/elexis-wiki-interface/spec/data/pull/ch.elexis.notes/doc/ChElexisIcpcViewsEpisodesview.mediawiki"
)
          regexp = /Episodes/i
          pp view if view.id.match(regexp)
          comps = view.id.split('.')
          pageName = comps[0..-2].collect{|x| x.capitalize}.join + 'Views'+view.id.split('.').last.capitalize
          puts "viewToPageName for #{plugin_id}/#{view.id} is #{pageName}" if $VERBOSE or  view.id.match(regexp)
          pageName
        end
        
        private
        def get_from_wiki_if_exists(plugin_id, pageName)
          content = @mw.get(pageName)
          out_name = File.join(@info.workspace_dir, plugin_id, 'doc', pageName + '.mediawiki')
          if content
            dirname = File.dirname(out_name)
            FileUtils.makedirs(dirname) unless File.directory?(dirname)
            ausgabe = File.open(out_name, 'w+')
            ausgabe.puts content
            ausgabe.close
          else
            puts "Could not fetch #{pageName} from #{@mw}" 
          end
          content
        end
        def pull_docs_views(plugin)
          id = plugin.symbolicName
          plugin.views.each{
            |id, view|
            pageName = viewToPageName(plugin.symbolicName, view)
            content = get_from_wiki_if_exists(plugin.symbolicName, pageName)
            @views_missing_documentation << pageName unless content
          }
        end
       def pull_docs_perspectives(plugin)
          id = plugin.symbolicName
          plugin.perspectives.each{
            |id, perspective|
            pageName = perspectiveToPageName(perspective)
            content = get_from_wiki_if_exists(plugin.symbolicName, pageName)
            @perspectives_missing_documentation << pageName unless content
          }
        end
        def pull_docs_plugins(plugin)
          id = plugin.symbolicName
          pageName = id.capitalize
          content = get_from_wiki_if_exists(plugin.symbolicName, pageName)
          @perspectives_missing_documentation << pageName unless content
        end
      end
      # Your code goes here...
    end
  end
end
