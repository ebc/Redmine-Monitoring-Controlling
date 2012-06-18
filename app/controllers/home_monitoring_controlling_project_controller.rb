class HomeMonitoringControllingProjectController < ApplicationController
  unloadable

  layout 'base'
  before_filter :find_project, :authorize
  menu_item :redmine_monitoring_controlling


  def subProjects(id)
     Project.find_by_sql("select * from projects where parent_id = #{id.to_i}")
  end

  def return_ids(id)
     array = Array.new
     array.push(id)
     subprojects = subProjects(id)
     subprojects.each do |project|
      array.push(return_ids(project.id))
     end

     return array
  end

  def index
    #get main project
    @project = Project.find_by_identifier(params[:id])

    #get projects and sub projects
    stringSqlProjectsSubPorjects = return_ids(@project.id).inspect.gsub("[","").gsub("]","")
    #stringSqlProjectsSubPorjects = return_ids(@project.id).inspect.gsub("[","").gsub("]","")
    @projects_subprojects = Project.find_by_sql("select * from projects where id in (#{stringSqlProjectsSubPorjects});")
    @all_project_issues = filter_issues Issue.find_by_sql("select * from issues where project_id in (#{stringSqlProjectsSubPorjects});")

    filter_str = params[:filter_team].blank? ? "FROM issues WHERE" : "FROM issues, users, groups_users WHERE issues.assigned_to_id = users.id
                        and users.id = groups_users.user_id and groups_users.group_id = #{params[:filter_team]} AND"

    filter_str += " issues.fixed_version_id = #{params[:filter_version]} AND" unless params[:filter_version].blank?
    #get statuses by main project and subprojects
    @statuses = IssueStatus.find_by_sql("SELECT *,
                                          ((SELECT COUNT(1) #{filter_str} project_id in (#{stringSqlProjectsSubPorjects}) and status_id = issue_statuses.id)
                                          /
                                          NULLIF((SELECT COUNT(1) #{filter_str} project_id in (#{stringSqlProjectsSubPorjects})),0))*100 as percent,
                                          (SELECT COUNT(1) #{filter_str} project_id in (#{stringSqlProjectsSubPorjects}) and status_id = issue_statuses.id)
                                          AS totalissues
                                          FROM issue_statuses;")

    #get management issues by main project
    @managementissues = Issue.find_by_sql("select 1 as id, '#{t :manageable_label}' as typemanagement, count(1) as totalissues
                                                #{filter_str} project_id in (#{stringSqlProjectsSubPorjects}) and due_date is not null
                                                union
                                                select 2 as id, '#{t :unmanageable_label}' as typemanagement, count(1) as totalissues
                                                #{filter_str} project_id in (#{stringSqlProjectsSubPorjects}) and due_date is null;")


    #get overdue issues for char by by project and subprojects
    @overdueissueschart = Issue.find_by_sql(["select 2 as id, '#{t :overdue_label}' as typeissue, count(1) as totalissuedelayed
                                                  #{filter_str} project_id in (#{stringSqlProjectsSubPorjects})
                                                  and due_date is not null
                                                  and due_date <  '#{Date.today}'
                                                  and status_id in (select id from issue_statuses where is_closed = ?)
                                                  union
                                                  select 1 as id, '#{t :delivered_label}' as typeissue, count(1) as totalissuedelayed
                                                  #{filter_str} project_id in (#{stringSqlProjectsSubPorjects})
                                                  and due_date is not null
                                                  and due_date < '#{Date.today}'
                                                  and status_id in (select id from issue_statuses where is_closed = ?)
                                                  union
                                                  select 3 as id, '#{t :tobedelivered_label}' as typeissue, count(1) as totalissuedelayed
                                                  #{filter_str} project_id in (#{stringSqlProjectsSubPorjects})
                                                  and due_date is not null
                                                  and due_date >= '#{Date.today}'
                                                  and status_id in (select id from issue_statuses where is_closed = ?)
                                                  order by 1;", false, true, false])


    #get overdueissues by project and subprojects
    @overdueissues   =   filter_issues Issue.find_by_sql(["select *
                                                    from issues
                                                    where project_id in (#{stringSqlProjectsSubPorjects})
                                                    and due_date is not null
                                                    and due_date < '#{Date.today}'
                                                    and status_id in (select id from issue_statuses where is_closed = ? )
                                                    order by due_date;",false])

    #get unmanagement issues by main project
    @unmanagementissues = filter_issues Issue.find_by_sql("select *
                                             from issues where project_id in (#{stringSqlProjectsSubPorjects}) 
                                             and due_date is null
                                             order by 1;")
  end

  private
  def find_project
    @project=Project.find(params[:id])
  end

  def filter_issues issues
    issues.select do |issue|
      keep = true
      unless params[:filter_team].blank?
        if issue.assigned_to.nil?
          keep = false
        else
          keep = !issue.assigned_to.groups.index{|group| group.id == params[:filter_team].to_i}.nil? 
        end
      end

      unless params[:filter_version].blank?
        if issue.fixed_version.nil?
          keep = false
        else
          keep = (issue.fixed_version.id == params[:filter_team].to_i)
        end
      end

      keep
    end
  end
end
