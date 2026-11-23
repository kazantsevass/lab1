class JobSerializer
  def self.summary(record)
    record.slice(*%i[name place company_id])
  end

  def self.detail(record)
    summary(record)
  end
end
