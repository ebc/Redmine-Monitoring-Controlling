class McHumanResourceMgmtProjectController < ApplicationController
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
    
=begin
    @statusesByAssigneds = Issue.find_by_sql("select assigned_to_id, (select firstname from users where id = assigned_to_id) as assigned_name,
           status_id, name as status,
         count(1) as totalassignedbystatuses 
    from issues, issue_statuses 
    where project_id in (#{stringSqlProjectsSubPorjects})
    and   issue_statuses.id = status_id
    group by assigned_to_id, assigned_name, status_id, status 
    order by 2,3;")
=end

    filter_str = params[:filter_team].blank? ? "FROM issues, issue_statuses WHERE" : "FROM issues, issue_statuses, users us, groups_users gu WHERE issues.assigned_to_id = us.id
                          and us.id = gu.user_id and gu.group_id = #{params[:filter_team]} AND"

    filter_str += " issues.fixed_version_id = #{params[:filter_version]} AND" unless params[:filter_version].blank?

    @statusesByAssigneds = Issue.find_by_sql("select assigned_to_id, (select firstname from users where id = assigned_to_id) as assigned_name,
                                              issue_statuses.id, issue_statuses.name, 
                                         	    (select COUNT(1) 
                                               #{filter_str.gsub('FROM issues, issue_statuses', 'FROM issues i').gsub('issues.', 'i.')} i.project_id in (#{stringSqlProjectsSubPorjects})
                                               and ((i.assigned_to_id = issues.assigned_to_id and i.assigned_to_id is not null)or(i.assigned_to_id is null and issues.assigned_to_id is null)) and i.status_id = issue_statuses.id) as totalassignedbystatuses
                                               #{filter_str} project_id in (#{stringSqlProjectsSubPorjects}) 
                                               group by assigned_to_id, assigned_name, issue_statuses.id, issue_statuses.name
                                               order by 2,3;")  
    
    
  end

  private
  def find_project
    @project=Project.find(params[:id])
  end


end