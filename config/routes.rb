Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  scope path: "v1", module: "api/v1", as: "v1", defaults: { format: :json } do
    resources :companies, except: %i[new edit] do
      put :mark_deleted, on: :member
      resources :jobs, only: %i[index show] do
        resources :applies, only: :index
      end
      resources :geeks, only: :index
    end
    resources :jobs, except: %i[new edit] do
      resources :geeks, only: :index
    end
    resources :geeks, except: %i[new edit] do
      put :resume, on: :member
      resources :applies, only: :index
    end
    resources :applies, except: %i[new edit] do
      member do
        put :read
        put :invite
      end
    end
  end

  match "/", to: "api/v1/base#catch_404", via: :all
  match "*path", to: "api/v1/base#catch_404", via: :all
end
