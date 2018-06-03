Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # In the development environment your application's code is reloaded on
  # every request. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.cache_classes = false

  # Do not eager load code on boot.
  config.eager_load = false

  # Show full error reports.
  config.consider_all_requests_local = true

  # Enable/disable caching. By default caching is disabled.
  if Rails.root.join('tmp/caching-dev.txt').exist?
    config.action_controller.perform_caching = true

    config.cache_store = :memory_store
    config.public_file_server.headers = {
      'Cache-Control' => "public, max-age=#{2.days.seconds.to_i}"
    }
  else
    config.action_controller.perform_caching = false

    config.cache_store = :null_store
  end

  # Don't care if the mailer can't send.
  config.action_mailer.raise_delivery_errors = false

  config.action_mailer.perform_caching = false

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log

  # Raise an error on page load if there are pending migrations.
  config.active_record.migration_error = :page_load

  # Debug mode disables concatenation and preprocessing of assets.
  # This option may cause significant delays in view rendering with a large
  # number of complex assets.
  config.assets.debug = true

  # Suppress logger output for asset requests.
  config.assets.quiet = true

  # Raises error for missing translations
  # config.action_view.raise_on_missing_translations = true

  # Use an evented file watcher to asynchronously detect changes in source code,
  # routes, locales, etc. This feature depends on the listen gem.
  config.file_watcher = ActiveSupport::EventedFileUpdateChecker

  # Para que no salgan las queries en consola
  config.active_record.logger = nil

  # API url
  ENV['api_url'] = "https://integracion-2018-dev.herokuapp.com/"  ## development
  #ENV['api_url'] = "https://integracion-2018-prod.herokuapp.com/"  ## production
  ENV['api_psswd'] = "TGVaa:#Dtih:kx4"  ## development
  #ENV['api_psswd'] = ".cZXvgT%MQjDLig"  ## production

  # API OC url
  ENV['api_oc_url'] = "https://integracion-2018-dev.herokuapp.com/oc/"  ## development
  #ENV['api_oc_url'] = "https://integracion-2018-prod.herokuapp.com/oc/"  ## production

  # SFTP de ordenes mayorias
  ENV['sftp_ordenes_url'] = "integradev.ing.puc.cl"  ## development
  #ENV['sftp_ordenes_url'] = "integracion.ing.puc.cl"  ## production
  ENV['sftp_ordenes_login'] = "grupo4"
  ENV['sftp_ordenes_psswd'] = "1ccWcVkAmJyrOfA"  ## development
  #ENV['sftp_ordenes_psswd'] = "U81Y9W1umtDDvON2w"  ## production

  # API banco url
  ENV['api_banco_url'] = "https://integracion-2018-dev.herokuapp.com/banco/"  ## development
  #ENV['api_banco_url'] = "https://integracion-2018-prod.herokuapp.com/banco/"  ## production

  # Informacion de los grupos
  $info_grupos = {  ## development
                   1 => { id: "5aee1697b347e00004615e98", id_banco: "5ad36945d6ed1f00049becad", url: "http://integra1.ing.puc.cl/public/stock" },
                   2 => { id: "5aee1697b347e00004615e99", id_banco: "5ad36945d6ed1f00049becae", url: "http://integra2.ing.puc.cl/public/stock" },
                   3 => { id: "5aee1697b347e00004615e9a", id_banco: "5ad36945d6ed1f00049becaf", url: "http://integra3.ing.puc.cl/public/stock" },
                   4 => { id: "5aee1697b347e00004615e9b", id_banco: "5ad36945d6ed1f00049becb4", url: "http://integra4.ing.puc.cl/public/stock" },
                   5 => { id: "5aee1697b347e00004615e9c", id_banco: "5ad36945d6ed1f00049becb7", url: "http://integra5.ing.puc.cl/public/stock" },
                   6 => { id: "5aee1697b347e00004615e9d", id_banco: "5ad36945d6ed1f00049becb1", url: "http://integra6.ing.puc.cl/api/v1/public/stock" },
                   7 => { id: "5aee1697b347e00004615e9e", id_banco: "5ad36945d6ed1f00049becb8", url: "http://integra7.ing.puc.cl/public/stock" },
                   8 => { id: "5aee1697b347e00004615e9f", id_banco: "5ad36945d6ed1f00049becb5", url: "http://integra8.ing.puc.cl/public/stock" },
                   9 => { id: "5aee1697b347e00004615ea0", id_banco: "5ad36945d6ed1f00049becb0", url: "http://integra9.ing.puc.cl/public/stock" }
                 }
=begin
  $info_grupos = {  ## production
                   1 => { id: "5aee1697b347e00004615e98", id_banco: "5aee1697b347e00004615ea3", url: "http://integra1.ing.puc.cl/public/stock" },
                   2 => { id: "5aee1697b347e00004615e99", id_banco: "5aee1697b347e00004615ea5", url: "http://integra2.ing.puc.cl/public/stock" },
                   3 => { id: "5aee1697b347e00004615e9a", id_banco: "5aee1697b347e00004615ea1", url: "http://integra3.ing.puc.cl/public/stock" },
                   4 => { id: "5aee1697b347e00004615e9b", id_banco: "5aee1697b347e00004615ea8", url: "http://integra4.ing.puc.cl/public/stock" },
                   5 => { id: "5aee1697b347e00004615e9c", id_banco: "5aee1697b347e00004615eaa", url: "http://integra5.ing.puc.cl/public/stock" },
                   6 => { id: "5aee1697b347e00004615e9d", id_banco: "5aee1697b347e00004615ea4", url: "http://integra6.ing.puc.cl/api/v1/public/stock" },
                   7 => { id: "5aee1697b347e00004615e9e", id_banco: "5aee1697b347e00004615ea2", url: "http://integra7.ing.puc.cl/public/stock" },
                   8 => { id: "5aee1697b347e00004615e9f", id_banco: "5aee1697b347e00004615ea6", url: "http://integra8.ing.puc.cl/public/stock" },
                   9 => { id: "5aee1697b347e00004615ea0", id_banco: "5aee1697b347e00004615eab", url: "http://integra9.ing.puc.cl/public/stock" }
                 }
=end

end
