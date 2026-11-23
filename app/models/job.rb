class Job < ApplicationRecord
  belongs_to :company
  has_many :applies
  scope :visible, -> { joins(:company).merge(Company.visible).where(deleted: false) }

  validates :name, :place, presence: true, length: { maximum: 255 }
  validates :company_id, presence: true, numericality: { only_integer: true }
  validates_associated :company
  validate :company_is_active, if: :will_save_change_to_company_id?
  validates :deleted, inclusion: { in: [ true, false ] }

  private

  def company_is_active
    errors.add(:company_id, "belongs to a deleted company") if company&.deleted?
  end
end
