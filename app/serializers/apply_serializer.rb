class ApplySerializer
  def self.summary(record)
    record.slice(*%i[job_id geek_id read invited])
  end

  def self.detail(record)
    record.slice(*%i[id job_id geek_id read invited])
  end
end
