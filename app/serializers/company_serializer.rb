class CompanySerializer
  def self.summary(record)
    record.slice(*%i[name location])
  end

  def self.detail(record)
    record.slice(*%i[id name location created_at updated_at])
  end
end
