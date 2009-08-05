# $Id$

class HudsonApplicationHooks < Redmine::Hook::ViewListener

  include ActionView::Helpers::DateHelper
  include ApplicationHelper

  def view_layouts_base_html_head(context = {})
    project = context[:project]
    return '' unless project
    controller = context[:controller]
    return '' unless controller
    action_name = controller.action_name
    return '' unless action_name

    if (controller.class.name == 'ProjectsController' and action_name == 'activity')
      settings = HudsonSettings.load(project)
      return '' unless settings
      o = ""
      o << "<style type='text/css'>"
      o << ".hudson-build { background-image: url(#{settings.url}favicon.ico); }"
      o << "</style>\n"
      return o
    end

    baseurl = url_for(:controller => 'hudson', :action => 'index', :id => project) + '/../../..'
    if (controller.class.name == 'IssuesController' and action_name == 'show')
      o = ""
      o << stylesheet_link_tag(baseurl + "/plugin_assets/redmine_hudson/stylesheets/hudson.css")
      o << javascript_include_tag(baseurl + "/plugin_assets/redmine_hudson/javascripts/build_result.js")
      return o
    end

  end

  def view_issues_show_description_bottom(context = {})
    return '' unless context[:issue]
    issue = context[:issue]

    o = ''
    o << "<script type='text/javascript'>" + "\n"
    o << "builds = $H();" + "\n"
    issue.changesets.each {|changeset|
      builds = HudsonBuild.find(:all, :order=>"#{HudsonBuild.table_name}.number",
                                :conditions=> ["#{HudsonBuildChangeset.table_name}.repository_id = ? and #{HudsonBuildChangeset.table_name}.revision = ?", issue.project.repository.id, changeset.revision],
                                :include=>:changesets)
      builds.each{|build|
        job = HudsonJob.find(:first, :conditions=>["#{HudsonJob.table_name}.id = ?", build.hudson_job_id])
        finished_at_tag = link_to(distance_of_time_in_words(Time.now, build.finished_at),
                                    {:controller => 'projects', :action => 'activity', :id => @project, :from => build.finished_at.to_date},
                                     :title => format_time(build.finished_at))
        o << "builds.set('#{changeset.revision}',"
        o << "new BuildResult('#{job.name}',#{build.number},'#{build.result}','#{build.finished_at}','#{finished_at_tag}','#{build.url}'));" + "\n"
      }
    }
    o << "Event.observe(window, 'load', add_build_info_to_changesets);" + "\n"
    o << "function add_build_info_to_changesets(){" + "\n"
    o << "  var messages = $$('div[class^=\"changeset\"] p');" + "\n"
    o << "  messages.each(function(message){" + "\n"
    o << "    if ( message.innerHTML.indexOf('repositories') > 0) {" + "\n"
    o << "  	  add_build_info_to_changeset(message);" + "\n"
    o << "    }" + "\n"
    o << "  });" + "\n"
    o << "};" + "\n"
    o << "function add_build_info_to_changeset(message){" + "\n"
    o << "  var keys = builds.keys();" + "\n"
    o << "  for( var index=0; index<keys.length; index++ ) {" + "\n"
    o << "    build = builds.get(keys[index]);" + "\n"
    o << "    if ( message.innerHTML.indexOf('#{l(:label_revision)} ' + keys[index]) > 0 ) { message.innerHTML += '<br>' + build.message(); }" + "\n"
    o << "  }" + "\n"
    o << "}" + "\n"
    o << "</script>"
  end
end