class Api::V1::JobsController < Api::V1::ResourcesController
  self.model = Job
  self.serializer = JobSerializer
  self.write_fields = %i[name place company_id]
  self.filter_fields = %i[name place]

  def destroy
    soft_delete(Job.find(params[:id]))
  end

  private

  def authorize_write(record, attributes)
    return if admin?
    raise Forbidden unless employer
    require_owner(employer, record.company_id) if record.persisted? || record.company_id
    require_owner(employer, attributes[:company_id]) if attributes[:company_id].present?
  end

  def collection
    company_id = request.path_parameters[:company_id]
    return Job.visible unless company_id

    Company.visible.find(company_id).jobs.where(deleted: false)
  end
end
