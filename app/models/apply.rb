class Apply < ApplicationRecord
  belongs_to :job
  belongs_to :geek

  validates :job_id, :geek_id, presence: true, numericality: { only_integer: true }
  validates_associated :job, :geek
  validates :read, :invited, inclusion: { in: [ true, false ] }
  validate :job_is_active, if: :will_save_change_to_job_id?

  private

  def job_is_active
    errors.add(:job_id, "is no longer available") if job && (job.deleted? || job.company&.deleted?)
  end
end
