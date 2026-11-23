class Company < ApplicationRecord
  has_many :jobs
  scope :visible, -> { where(deleted: false) }

  validates :name, :location, presence: true, length: { maximum: 255 }
  validates :deleted, inclusion: { in: [ true, false ] }
end
