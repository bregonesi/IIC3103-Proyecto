Rails.application.routes.draw do
  resources :invoices
  resources :orden_compras
  resources :transferencia
  get '/transferencias', to: 'transferencia#index'
  resources :ocs_generadas
  resources :oc_requests
  resources :sftp_orders
  # This line mounts Spree's routes at the root of your application.
  # This means, any requests to URLs such as /products, will go to
  # Spree::ProductsController.
  # If you would like to change where this engine is mounted, simply change the
  # :at option to something different.
  #
  # We ask that you don't use the :as option here, as Spree relies on it being
  # the default of "spree".
  mount Spree::Core::Engine, at: '/'
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html


  get '/public/stock', to: 'api#stock_publico'
  get '/private/stock', to: 'api#stock_privado'

  post '/hook', to: 'hook#materias_primas'
  get '/hook_list', to: 'hook#list_requests'
  get '/fabricar_list', to: 'hook#list_fabricar_requests'
  
  put '/public/oc/:id', to: 'endpoint#recibir_oc'
  post '/public/oc/:id/notification', to: 'endpoint#respuesta_oc'

  resources :orders do
    resource :checkout, :controller => 'spree/checkout' do
      member do
        get :api_gateway_url
        get :api_gateway_success
        get :api_gateway_fail
      end
    end
  end

end
