# frozen_string_literal: true

PromptCanary::Engine.routes.draw do
  root to: "dashboard/prompts#index"
  scope module: :dashboard do
    resources :prompts, only: %i[index show], param: :name do
      member do
        post :promote
      end
    end
  end
end
