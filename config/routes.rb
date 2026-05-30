PromptCanary::Engine.routes.draw do
  root to: "dashboard/prompts#index"
  resources :prompts, only: %i[index show], param: :name
end
