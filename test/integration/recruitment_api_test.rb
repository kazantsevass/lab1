require "test_helper"

class RecruitmentApiTest < ActionDispatch::IntegrationTest
  setup do
    @company = Company.create!(name: "First", location: "London")
    @other = Company.create!(name: "Second", location: "Paris")
    @job = @company.jobs.create!(name: "Rails", place: "Remote")
    @geek = Geek.create!(name: "Mike", stack: "Ruby")
    @apply = @job.applies.create!(geek: @geek)
  end

  def json
    assert_equal "application/json", response.media_type
    response.parsed_body
  end

  def bearer(record)
    { "Authorization" => "Bearer #{record.signed_id(purpose: :api_access)}" }
  end

  def as_admin
    previous = ENV["APP1_ADMIN_TOKEN"]
    token = SecureRandom.hex(24)
    ENV["APP1_ADMIN_TOKEN"] = token
    yield({ "Authorization" => "Bearer #{token}" })
  ensure
    ENV["APP1_ADMIN_TOKEN"] = previous
  end

  test "public collections use filters, stable pages and explicit projections" do
    get "/v1/companies", params: { location: "London", name: "First" }
    assert_response :ok
    assert_equal [ { "name" => "First", "location" => "London" } ], json.fetch("companies")
    get "/v1/companies?limit=1&offset=1"
    assert_equal [ "Second" ], json.fetch("companies").pluck("name")
    get "/v1/jobs?place=Remote&name=Rails"
    assert_equal [ { "name" => "Rails", "place" => "Remote", "company_id" => @company.id } ], json.fetch("jobs")
    get "/v1/geeks?name=Mike&stack=Ruby"
    assert_equal [ "Mike" ], json.fetch("geeks").pluck("name")
    get "/v1/applies?read=false&invited=false", headers: bearer(@company)
    assert_equal [ false ], json.fetch("applies").pluck("invited")
    get "/v1/companies/#{@company.id}"
    assert_equal %w[created_at id location name updated_at], json.keys.sort
  end

  test "nested requests enforce ownership and return distinct applicants" do
    @company.jobs.create!(name: "Ruby", place: "Local").applies.create!(geek: @geek)
    get "/v1/companies/#{@company.id}/jobs"
    assert_equal 2, json.fetch("jobs").size
    get "/v1/companies/#{@company.id}/jobs/#{@job.id}"
    assert_equal "Rails", json.fetch("name")
    get "/v1/companies/#{@company.id}/jobs/#{@job.id}/applies", headers: bearer(@company)
    assert_equal [ @geek.id ], json.fetch("applies").pluck("geek_id")
    get "/v1/companies/#{@company.id}/geeks", headers: bearer(@company)
    assert_equal [ "Mike" ], json.fetch("geeks").pluck("name")
    get "/v1/jobs/#{@job.id}/geeks", headers: bearer(@company)
    assert_equal [ "Mike" ], json.fetch("geeks").pluck("name")
    get "/v1/geeks/#{@geek.id}/applies?read=true", headers: bearer(@company)
    assert_empty json.fetch("applies")
    get "/v1/companies/#{@other.id}/jobs/#{@job.id}/applies", headers: bearer(@company)
    assert_response :not_found
    get "/v1/companies/#{@other.id}/jobs/#{@job.id}"
    assert_response :not_found
  end

  test "create, update, resume and application decisions" do
    post "/v1/companies", params: { company: { name: "New", location: "Berlin", deleted: true } }, as: :json
    assert_response :created
    owner = { "Authorization" => "Bearer #{response.headers.fetch("X-Access-Token")}" }
    company_id = json.fetch("id")
    patch "/v1/companies/#{company_id}", params: { location: "Rome" }, headers: owner, as: :json
    assert_equal "Rome", json.fetch("location")
    post "/v1/jobs", params: { name: "Go", place: "Local", company_id: company_id }, headers: owner, as: :json
    assert_response :created
    assert_equal "Go", json.fetch("name")
    post "/v1/geeks", params: { name: "New", stack: "Go" }, as: :json
    assert_response :created
    candidate = { "Authorization" => "Bearer #{response.headers.fetch("X-Access-Token")}" }
    geek_id = json.fetch("id")
    put "/v1/geeks/#{geek_id}/resume", params: { resume: "Go developer", name: "Ignore" }, headers: candidate, as: :json
    assert_equal "Go developer", json.fetch("resume")
    assert_equal "New", json.fetch("name")
    post "/v1/applies", params: { job_id: @job.id, geek_id: geek_id }, headers: candidate, as: :json
    assert_response :created
    id = json.fetch("id")
    put "/v1/applies/#{id}/read", headers: bearer(@company)
    assert_equal true, json.fetch("read")
    put "/v1/applies/#{id}/invite", headers: bearer(@company)
    assert_equal true, json.fetch("invited")
    get "/v1/geeks/#{geek_id}/applies?read=true&invited=true", headers: bearer(@company)
    assert_equal [ @job.id ], json.fetch("applies").pluck("job_id")
    as_admin do |headers|
      delete "/v1/geeks/#{geek_id}", headers: headers
      assert_response :conflict
      delete "/v1/applies/#{id}", headers: headers
      assert_response :ok
      delete "/v1/geeks/#{geek_id}", headers: headers
      assert_response :ok
    end
  end

  test "soft deletion is admin-only, repeatable and hides descendants" do
    put "/v1/companies/#{@company.id}/mark_deleted"
    assert_response :forbidden
    as_admin do |headers|
      delete "/v1/jobs/#{@job.id}", headers: headers
      assert_equal @job.id, json.fetch("deleted_job")
      delete "/v1/jobs/#{@job.id}", headers: headers
      assert_equal "not_modified", json.fetch("deleted_already")
      @company.jobs.create!(name: "Visible until company deletion", place: "Remote")
      put "/v1/companies/#{@company.id}/mark_deleted", headers: headers
      assert_equal({ "deleted_company" => @company.id, "code" => 200, "status" => "success" }, json)
      delete "/v1/companies/#{@company.id}", headers: headers
      assert_equal "not_modified", json.fetch("deleted_already")
    end
    assert @company.reload.deleted?
    assert @job.reload.deleted?
    get "/v1/jobs"
    assert_empty json.fetch("jobs")
    get "/v1/companies/#{@company.id}/jobs"
    assert_response :not_found
    get "/v1/applies", headers: bearer(@geek)
    assert_empty json.fetch("applies")
  end

  test "validation, missing records, unknown methods and suppressed HTTP codes" do
    post "/v1/jobs", params: { name: "Ruby", place: "Remote" }, headers: bearer(@company), as: :json
    assert_response 422
    assert json.fetch("errors").key?("company_id")
    get "/v1/jobs/0"
    assert_response :not_found
    assert_equal({ "error" => "No such record in Database; check params", "status" => "not_found" }, json)
    post "/v1/unknown"
    assert_response :not_found
    assert_equal({ "error" => "No route matches; check routes", "status" => "no_route" }, json)
    get "/v1/jobs/0?suppress_response_code=true"
    assert_response :ok
    assert_equal 404, json.fetch("code")
    get "/v1/jobs?offset=-1"
    assert_response :bad_request
    get "/v1/applies?invited=other", headers: bearer(@company)
    assert_response :bad_request
  end
  test "only owners can change profiles, vacancies and decisions" do
    patch "/v1/jobs/#{@job.id}", params: { name: "Other" }, headers: bearer(@other), as: :json
    assert_response :forbidden
    patch "/v1/jobs/#{@job.id}", params: { company_id: @other.id }, headers: bearer(@company), as: :json
    assert_response :forbidden
    assert_equal @company.id, @job.reload.company_id
    put "/v1/geeks/#{@geek.id}/resume", params: { resume: "Other" }, headers: bearer(@company), as: :json
    assert_response :forbidden
    put "/v1/applies/#{@apply.id}/invite", headers: bearer(@geek)
    assert_response :forbidden
    get "/v1/applies/#{@apply.id}", headers: bearer(@other)
    assert_response :not_found
    post "/v1/applies", params: { job_id: @job.id, geek_id: @geek.id, read: true }, headers: bearer(@geek), as: :json
    assert_response :forbidden
    get "/v1/applies"
    assert_response :forbidden
  end
end
