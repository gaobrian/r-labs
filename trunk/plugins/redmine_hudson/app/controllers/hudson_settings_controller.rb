# $Id$
# To change this template, choose Tools | Templates
# and open the template in the editor.

require "rexml/document"
require 'hudson_exceptions'

class HudsonSettingsController < ApplicationController
  unloadable
  layout 'base'

  before_filter :find_project
  before_filter :find_hudson
  before_filter :authorize
  before_filter :clear_flash

  include RexmlHelper
  include HudsonHelper

  def edit
    if (params[:settings] != nil)
      @hudson.settings.project_id = @project.id
      @hudson.settings.url = HudsonSettings.add_last_slash_to_url(params[:settings].fetch(:url))
      @hudson.settings.job_filter = HudsonSettings.to_value(params[:settings].fetch(:jobs))
      @hudson.settings.auth_user = params[:settings].fetch(:auth_user)
      @hudson.settings.auth_password = params[:settings].fetch(:auth_password)
      @hudson.settings.get_build_details = check_box_to_boolean(params[:settings][:get_build_details])
      @hudson.settings.show_compact = check_box_to_boolean(params[:settings][:show_compact])
      @hudson.settings.look_and_feel = params[:settings].fetch(:look_and_feel)

      update_health_reports params

      if ( @hudson.settings.save )
        add_job
        update_job_settings params
        find_hudson # 一度設定を読み直さないと、destory したものが残るので ( delete_if の方が分かりやすい？ )
        flash[:notice] = l(:notice_successful_update)
      end

    end

    # この find は、外部のサーバ(Hudson)にアクセスするので、before_filter には入れない
    find_hudson_jobs(@hudson.settings.url)

  rescue HudsonApiException => error
    flash.now[:error] = error.message
  end

  def joblist
    begin
      # この find は、外部のサーバ(Hudson)にアクセスするので、before_filter には入れない
      find_hudson_jobs(HudsonSettings.add_last_slash_to_url(params[:url]))
    rescue HudsonApiException => error
      @error = error.message
    end
    render :layout => false, :template => 'hudson_settings/_joblist.rhtml'
  end

  def delete_builds
    find_hudson_jobs(@hudson.settings.url)
    job = HudsonJob.find(params[:job_id])
    ActiveRecord::Base::transaction() do
      job.destroy_builds
      job.latest_build_number = ""
      job.save!
    end if job
  ensure
    render :layout => false, :template => 'hudson_settings/_joblist.rhtml'
  end

  def delete_history
    jobs = HudsonJob.find :all, :order => "#{HudsonJob.table_name}.name",
                          :conditions => ["#{HudsonJob.table_name}.project_id = ?", @project.id]
    jobs.each {|job|
      ActiveRecord::Base::transaction() do
        job.destroy_builds
        job.destroy
      end
    }

    flash[:notice] = l(:notice_successful_delete)
  rescue Exception => error
    flash[:error] = error.message
  ensure
    find_hudson_jobs(@hudson.settings.url)
    render(:action => "edit")
  end

private
  def find_project
    @project = Project.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_hudson
    @hudson = Hudson.find_by_project_id(@project.id)
  end

  def clear_flash
    flash.clear
  end

  def find_hudson_jobs(url)
    @jobs = []

    return if url == nil || url.length == 0

    api_url = "#{url}api/xml?depth=0"

    # Open the feed and parse it
    content = open_hudson_api(api_url, @hudson.settings.auth_user, @hudson.settings.auth_password)
    doc = REXML::Document.new content
    doc.elements.each("hudson/job") do |element|
      @jobs << get_element_value(element, "name")
    end
  end

  def update_health_reports(params)

    return unless params[:health_report_settings]
    
    params[:health_report_settings].each do |id, hrs|
      setting = @hudson.settings.health_report_settings.detect {|item| item.id == id.to_i}
      next unless setting

      if HudsonSettingsHealthReport.is_blank?(hrs)
        setting.destroy
        next
      end

      setting.update_from_hash(hrs)
      setting.save
    end

    return unless params[:new_health_report_settings]

    params[:new_health_report_settings].each do |id, hrs|
      next if HudsonSettingsHealthReport.is_blank?(hrs)
      @hudson.settings.health_report_settings << HudsonSettingsHealthReport.new(hrs)
    end

  end

  def add_job
    HudsonSettings.to_array(@hudson.settings.job_filter).each do |job_name|
      next if @hudson.get_job(job_name).is_a?(HudsonJob)
      job = @hudson.add_job(job_name)
      job.save!
    end
  end

  def update_job_settings(params)
    return unless params[:job_settings]
    @hudson.jobs.each do |job|
      my_params = params[:job_settings][job.id.to_s]
      next unless my_params

      build_rotator_days_to_keep = my_params[:build_rotator_days_to_keep] != "" ? my_params[:build_rotator_days_to_keep] : -1
      build_rotator_num_to_keep = my_params[:build_rotator_num_to_keep] != "" ? my_params[:build_rotator_num_to_keep] : -1

      job.job_settings.build_rotate = check_box_to_boolean(my_params[:build_rotate])
      job.job_settings.build_rotator_days_to_keep = build_rotator_days_to_keep
      job.job_settings.build_rotator_num_to_keep = build_rotator_num_to_keep
      job.job_settings.save!
    end
  end

  def destroy_garbage_jobs()
    jobs = HudsonJob.find :all, :order => "#{HudsonJob.table_name}.name",
                           :conditions => ["#{HudsonJob.table_name}.project_id = ?", @project.id]
    jobs.each {|job|
      next if @hudson.settings.job_include?(job.name)
      ActiveRecord::Base::transaction() do
        job.destroy_builds
        job.destroy
      end
    }
  end

end
