Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      post "login", to: "sessions#create"
      get "balance", to: "balances#show"
      post "deposit", to: "deposits#create"
    end
  end

  get "up", to: proc { [200, {}, ["OK"]] }
end
