class McTimeMgmtProjectController < ApplicationController
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

    filter_str = params[:filter_team].blank? ? "FROM issues WHERE" : "FROM issues, users, groups_users WHERE issues.assigned_to_id = users.id
                        and users.id = groups_users.user_id and groups_users.group_id = #{params[:filter_team]} AND"

    filter_str += " issues.fixed_version_id = #{params[:filter_version]} AND" unless params[:filter_version].blank?


    @issuesSpentHours = Issue.find_by_sql("select issues.due_date, sum(issues.estimated_hours) as sumestimatedhours,
                                           (select sum(hours) from time_entries where project_id in (#{stringSqlProjectsSubPorjects}) and created_on <= issues.due_date ) as sumspenthours
                                           #{filter_str} issues.project_id in (#{stringSqlProjectsSubPorjects})
                                           and due_date is not null
                                           and parent_id is null
                                           and due_date <= issues.due_date
                                           group by issues.due_date 
                                           order by due_date;")    
                                        

    @spentHoursByVersion = Issue.find_by_sql("select versions.name as version, versions.effective_date, sum(issues.estimated_hours) as estimated_hours, 
                                             (select sum(i.estimated_hours) 
                                              #{filter_str.gsub('FROM issues', 'FROM issues i').gsub('issues.','i.')} i.project_id in (#{stringSqlProjectsSubPorjects})
                                              and i.fixed_version_id = versions.id
                                              and i.due_date is not null
                                              and i.parent_id is null 
                                              and i.due_date <= versions.effective_date) as sumestimatedhours,
                                             (select sum(hours) 
                                              #{filter_str.gsub('FROM issues', 'FROM issues i, time_entries t').gsub('issues.','i.')} i.project_id in (#{stringSqlProjectsSubPorjects})
                                              and i.project_id = t.project_id
                                              and i.parent_id is null
                                              and i.id = t.issue_id
                                              and i.fixed_version_id = versions.id
                                              and t.created_on <= versions.effective_date) as sumspenthours
                                             #{filter_str.gsub('FROM issues', 'FROM issues, versions')} issues.project_id in (#{stringSqlProjectsSubPorjects})
                                             and issues.parent_id is null
                                             and issues.fixed_version_id = versions.id
                                             and due_date <= versions.effective_date
                                             group by versions.id, versions.name, versions.effective_date
                                             order by versions.effective_date;")
                                      

  end

  private
  def find_project
    @project=Project.find(params[:id])
  end


end
