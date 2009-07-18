# $Id$
require 'redmine'
require 'hudson_application_hooks'

Redmine::Plugin.register :redmine_hudson do
  name 'Redmine Hudson plugin'
  author 'Toshiyuki Ando r-labs'
  url "http://www.r-labs.org/repositories/show/hudson" if respond_to?(:url)
  description 'This is a Hudson plugin for Redmine'
  version '0.1.6'
  requires_redmine :version_or_higher => '0.8.0'

  project_module :hudson do
    # パーミッション設定。
    permission :view_hudson, {:hudson => [:index, :history]}
    permission :build_hudson, {:hudson => [:build]}, :require => :member
    permission :edit_hudson_settings, {:hudson_settings => [:edit, :joblist, :delete_history]}, :require => :member
  end

  menu :project_menu, :hudson, { :controller => :hudson, :action => :index }, :param => :id, :caption => :label_hudson

  activity_provider :hudson, :class_name => 'HudsonBuild', :default => false

  Redmine::WikiFormatting::Macros.register do
    desc "This is my macro link to hudson"
    macro :build do |obj, args|
      return nil if args.length < 2 # require JobName, BuildNumber
      return nil if @project == nil
      settings = HudsonSettings.load(@project)
      return nil if settings == nil
      name = args[0].strip
      number = args[1].strip
      return link_to "Build:#{name} ##{number}", URI.escape("#{settings.url}job/#{name}/#{number}/")
    end
  end

end
