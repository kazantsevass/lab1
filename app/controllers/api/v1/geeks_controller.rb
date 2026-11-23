class Api::V1::GeeksController < Api::V1::ResourcesController
  self.model = Geek
  self.serializer = GeekSerializer
  self.write_fields = %i[name stack resume]
  self.filter_fields = %i[name stack]

  def resume
    record = Geek.find(params[:id])
    require_owner(applicant, record.id)
    attributes = attributes_for_write
    raise ActionController::BadRequest, "Missing resume" unless attributes.key?(:resume)
    record.update!(resume: attributes[:resume])
    render_record(record)
  end

  def destroy
    super
  rescue ActiveRecord::InvalidForeignKey
    error_response("Geek has applications", "conflict", 409)
  end

  private

  def authorize_write(record, _attributes)
    require_owner(applicant, record.id) if record.persisted?
  end

  def collection
    path = request.path_parameters
    if path[:company_id]
      jobs = Company.visible.find(path[:company_id]).jobs.where(deleted: false)
      require_owner(employer, path[:company_id])
      Geek.joins(:applies).where(applies: { job_id: jobs.select(:id) }).distinct
    elsif path[:job_id]
      job = Job.visible.find(path[:job_id])
      require_owner(employer, job.company_id)
      Geek.joins(:applies).where(applies: { job_id: job.id }).distinct
    else
      Geek.all
    end
  end
end
