PromptCanary::Engine.routes.draw do
  root to: "dashboard/prompts#index"
  scope module: :dashboard do
    resources :prompts, only: %i[index show], param: :name
  end
end
