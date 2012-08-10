Atrium::Engine.routes.draw do
  resources :collections do
    resources :exhibits do
      member do
        get :include_filter
        get :exclude_filer
      end
    end
    resources :showcases
  end
  resources :exhibits do
    resources :showcases
  end

  resources :showcases, :only => [:show]
    resources :descriptions do
      resources :essays
  end
  root :to => "collections#index"

end
