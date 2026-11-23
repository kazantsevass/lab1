local_origin = Rails.env.development? ? "http://localhost:5173" : ""
allowed_origins = ENV.fetch("CORS_ORIGINS", local_origin).split(",").map(&:strip).reject(&:empty?)

if allowed_origins.any?
  Rails.application.config.middleware.insert_before 0, Rack::Cors do
    allow do
      origins(*allowed_origins)
      resource "/v1/*", headers: :any, expose: %w[Location X-Access-Token], methods: %i[get head post put patch delete options]
    end
  end
end
