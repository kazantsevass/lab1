class Api::V1::AppliesController < Api::V1::ResourcesController
  self.model = Apply
  self.serializer = ApplySerializer
  self.write_fields = %i[job_id geek_id read invited]
  self.filter_fields = %i[read invited]

  def read
    record = collection.find(params[:id])
    require_owner(employer, record.job.company_id)
    record.update!(read: true)
    render_record(record)
  end

  def invite
    record = collection.find(params[:id])
    require_owner(employer, record.job.company_id)
    record.update!(invited: true)
    render_record(record)
  end

  private

  def authorize_write(record, attributes)
    return if admin?
    if record.new_record?
      require_owner(applicant, record.geek_id)
      raise Forbidden if record.read? || record.invited?
    else
      require_owner(employer, record.job.company_id)
      raise Forbidden if attributes.keys.intersect?(%w[job_id geek_id])
    end
  end

  def collection
    records = visible_applications
    path = request.path_parameters
    if path[:company_id]
      job = Company.visible.find(path[:company_id]).jobs.where(deleted: false).find(path[:job_id])
      records.where(job: job)
    elsif path[:geek_id]
      records.where(geek: Geek.find(path[:geek_id]))
    else
      records
    end
  end

  def visible_applications
    jobs = Job.visible
    return Apply.where(job_id: jobs.select(:id)) if admin?
    return Apply.where(job_id: jobs.where(company: employer).select(:id)) if employer
    return applicant.applies.where(job_id: jobs.select(:id)) if applicant
    raise Forbidden
  end
end
