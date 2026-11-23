class Geek < ApplicationRecord
  has_many :applies

  validates :name, :stack, presence: true, length: { maximum: 255 }
end
