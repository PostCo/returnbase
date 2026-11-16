Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    get "health", to: "health#show"

    resource :session, only: %i[create destroy]
    get "me", to: "me#show"

    resources :returns, only: %i[index show] do
      get :export, on: :collection
      member do
        post :approve, :reject, :receive, :resolve, :cancel, :send_to_store_box
        post :request_label, :move
        patch :items
      end
    end

    resources :locations, only: %i[index update] do
      member { post :archive, :unarchive, :make_default }
    end
    resource :shop, only: %i[show update]
    resources :integrations, only: :index
    resource :store_box_integration, only: %i[show create update] do
      patch :credentials
      post :activate, :deactivate
      get :warehouses
    end

    namespace :shopper do
      resources :shops, only: :index
      post "lookup", to: "orders#lookup"
      resources :returns, only: %i[create show], param: :number do
        post :cancel, on: :member
      end
    end
  end

  post "webhooks/quickpost", to: "webhooks/quickpost#create"
  post "webhooks/shipping", to: "webhooks/shipping#create"

  namespace :admin do
    get "parcel_dock", to: "parcel_dock#index"
    post "parcel_dock/:shop_id", to: "parcel_dock#update", as: :parcel_dock_shop
    post "demo_reset", to: "demo_resets#create"
  end
end
