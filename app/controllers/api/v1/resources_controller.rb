class Api::V1::ResourcesController < Api::V1::BaseController
  class_attribute :model, :serializer, :write_fields, :filter_fields
  before_action :require_admin, only: :destroy

  def index
    records = collection.order(:id)
    filter_fields.each do |field|
      next unless request.query_parameters.key?(field.to_s)

      value = request.query_parameters[field.to_s]
      unless value.is_a?(String) && (model.type_for_attribute(field.to_s).type != :boolean || %w[true false].include?(value))
        raise ActionController::BadRequest, "Invalid #{field} filter"
      end
      records = records.where(field => value)
    end
    records = records.limit(page_number(:limit)).offset(page_number(:offset))
    respond({ controller_name => records.map { |record| serializer.summary(record) } })
  end

  def show
    render_record(collection.find(params[:id]))
  end

  def create
    attributes = attributes_for_write
    record = model.new(attributes)
    authorize_write(record, attributes)
    record.save!
    response.set_header("Location", polymorphic_url([ :v1, record ]))
    if record.is_a?(Company) || record.is_a?(Geek)
      response.set_header("X-Access-Token", record.signed_id(purpose: :api_access, expires_in: 30.days))
      response.set_header("Cache-Control", "no-store")
    end
    render_record(record, 201)
  end

  def update
    record = collection.find(params[:id])
    record.with_lock do
      attributes = attributes_for_write
      authorize_write(record, attributes)
      record.update!(attributes)
    end
    render_record(record)
  end

  def destroy
    record = model.find(params[:id])
    record.destroy!
    respond({ id: record.id, status: "success" })
  end

  private

  def collection
    model.all
  end

  def attributes_for_write
    key = model.model_name.param_key
    source = params.fetch(key, params)
    raise ActionController::BadRequest, "Expected an object for #{key}" unless source.is_a?(ActionController::Parameters)
    source.permit(*write_fields)
  end

  def page_number(key)
    value = request.query_parameters[key.to_s]
    return if value.nil?
    unless value.is_a?(String) && value.match?(/\A\d{1,19}\z/) && value.to_i <= 2**63 - 1
      raise ActionController::BadRequest, "#{key} must be a non-negative integer within bigint range"
    end
    value.to_i
  end

  def render_record(record, code = 200)
    respond(serializer.detail(record), code)
  end

  def soft_delete(record)
    record.with_lock do
      if record.deleted?
        respond({ deleted_already: "not_modified" })
      else
        record.update!(deleted: true)
        respond({ "deleted_#{model.model_name.param_key}" => record.id, code: 200, status: "success" })
      end
    end
  end
end
