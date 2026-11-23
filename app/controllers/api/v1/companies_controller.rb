class Api::V1::CompaniesController < Api::V1::ResourcesController
  before_action :require_admin, only: :mark_deleted
  self.model = Company
  self.serializer = CompanySerializer
  self.write_fields = self.filter_fields = %i[name location]

  def destroy
    soft_delete(Company.find(params[:id]))
  end
  alias_method :mark_deleted, :destroy

  private

  def authorize_write(record, _attributes)
    require_owner(employer, record.id) if record.persisted?
  end

  def collection
    Company.visible
  end
end
