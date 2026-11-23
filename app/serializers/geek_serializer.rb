class GeekSerializer
  def self.summary(record)
    record.slice(*%i[name stack])
  end

  def self.detail(record)
    record.slice(*%i[id name stack resume])
  end
end
