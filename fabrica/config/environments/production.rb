Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.cache_classes = true

  # Eager load code on boot. This eager loads most of Rails and
  # your application in memory, allowing both threaded web servers
  # and those relying on copy on write to perform better.
  # Rake tasks automatically ignore this option for performance.
  config.eager_load = true

  # Full error reports are disabled and caching is turned on.
  config.consider_all_requests_local       = false
  config.action_controller.perform_caching = true

  # Attempt to read encrypted secrets from `config/secrets.yml.enc`.
  # Requires an encryption key in `ENV["RAILS_MASTER_KEY"]` or
  # `config/secrets.yml.key`.
  config.read_encrypted_secrets = true

  # Disable serving static files from the `/public` folder by default since
  # Apache or NGINX already handles this.
  config.public_file_server.enabled = ENV['RAILS_SERVE_STATIC_FILES'].present?

  # Compress JavaScripts and CSS.
  config.assets.js_compressor = :uglifier
  # config.assets.css_compressor = :sass

  # Do not fallback to assets pipeline if a precompiled asset is missed.
  config.assets.compile = false

  # `config.assets.precompile` and `config.assets.version` have moved to config/initializers/assets.rb

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.action_controller.asset_host = 'http://assets.example.com'

  # Specifies the header that your server uses for sending files.
  # config.action_dispatch.x_sendfile_header = 'X-Sendfile' # for Apache
  # config.action_dispatch.x_sendfile_header = 'X-Accel-Redirect' # for NGINX

  # Mount Action Cable outside main process or domain
  # config.action_cable.mount_path = nil
  # config.action_cable.url = 'wss://example.com/cable'
  # config.action_cable.allowed_request_origins = [ 'http://example.com', /http:\/\/example.*/ ]

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  # config.force_ssl = true

  # Use the lowest log level to ensure availability of diagnostic information
  # when problems arise.
  config.log_level = :warn

  # Prepend all log lines with the following tags.
  config.log_tags = [ :request_id ]

  # Use a different cache store in production.
  # config.cache_store = :mem_cache_store

  # Use a real queuing backend for Active Job (and separate queues per environment)
  # config.active_job.queue_adapter     = :resque
  # config.active_job.queue_name_prefix = "fabrica_#{Rails.env}"
  config.action_mailer.perform_caching = false

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = false

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Send deprecation notices to registered listeners.
  config.active_support.deprecation = :notify

  # Use default logging formatter so that PID and timestamp are not suppressed.
  config.log_formatter = ::Logger::Formatter.new

  # Use a different logger for distributed setups.
  # require 'syslog/logger'
  # config.logger = ActiveSupport::TaggedLogging.new(Syslog::Logger.new 'app-name')

  if ENV["RAILS_LOG_TO_STDOUT"].present?
    logger           = ActiveSupport::Logger.new(STDOUT)
    logger.formatter = config.log_formatter
    config.logger    = ActiveSupport::TaggedLogging.new(logger)
  end

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # API url
  #ENV['api_url'] = "https://integracion-2018-dev.herokuapp.com/"  ## development
  ENV['api_url'] = "https://integracion-2018-prod.herokuapp.com/"  ## production
  #ENV['api_psswd'] = "TGVaa:#Dtih:kx4"  ## development
  ENV['api_psswd'] = ".cZXvgT%MQjDLig"  ## production

  # API OC url
  #ENV['api_oc_url'] = "https://integracion-2018-dev.herokuapp.com/oc/"  ## development
  ENV['api_oc_url'] = "https://integracion-2018-prod.herokuapp.com/oc/"  ## production

  # SFTP de ordenes mayorias
  #ENV['sftp_ordenes_url'] = "integradev.ing.puc.cl"  ## development
  ENV['sftp_ordenes_url'] = "integracion.ing.puc.cl"  ## production
  ENV['sftp_ordenes_login'] = "grupo4"
  #ENV['sftp_ordenes_psswd'] = "1ccWcVkAmJyrOfA"  ## development
  ENV['sftp_ordenes_psswd'] = "U81Y9W1umtDDvON2w"  ## production

  # API banco url
  #ENV['api_banco_url'] = "https://integracion-2018-dev.herokuapp.com/banco/"  ## development
  ENV['api_banco_url'] = "https://integracion-2018-prod.herokuapp.com/banco/"  ## production

  # API sii url
  #ENV['api_sii_url'] = "https://integracion-2018-dev.herokuapp.com/sii/"  ## development
  ENV['api_sii_url'] = "https://integracion-2018-prod.herokuapp.com/sii/"  ## production

  # Compras b2b
  ENV['url_notificacion_oc'] = "http://integra4.ing.puc.cl/public/oc/{_id}/notification"
=begin
  $info_grupos = {  ## development
                   1 => { id: "5ad36945d6ed1f00049beca4", id_banco: "5ad36945d6ed1f00049becad", almacen: "5ad36a25d6ed1f00049becbf", stock_url: "http://dev.integra1.ing.puc.cl/public/stock", oc_url: "http://dev.integra1.ing.puc.cl/public/oc/" },
                   2 => { id: "5ad36945d6ed1f00049beca5", id_banco: "5ad36945d6ed1f00049becae", almacen: "5ad36a26d6ed1f00049bf412", stock_url: "http://dev.integra2.ing.puc.cl/public/stock", oc_url: "http://dev.integra2.ing.puc.cl/public/oc/" },
                   3 => { id: "5ad36945d6ed1f00049beca6", id_banco: "5ad36945d6ed1f00049becaf", almacen: "5ad36a27d6ed1f00049bfc04", stock_url: "http://dev.integra3.ing.puc.cl/public/stock", oc_url: "http://dev.integra3.ing.puc.cl/public/oc/" },
                   4 => { id: "5ad36945d6ed1f00049beca7", id_banco: "5ad36945d6ed1f00049becb4", almacen: "5ad36a28d6ed1f00049c0138", stock_url: "http://dev.integra4.ing.puc.cl/public/stock", oc_url: "http://dev.integra4.ing.puc.cl/public/oc/" },
                   5 => { id: "5ad36945d6ed1f00049beca8", id_banco: "5ad36945d6ed1f00049becb7", almacen: "5ad36a29d6ed1f00049c0948", stock_url: "http://dev.integra5.ing.puc.cl/public/stock", oc_url: "http://dev.integra5.ing.puc.cl/public/oc/" },
                   6 => { id: "5ad36945d6ed1f00049beca9", id_banco: "5ad36945d6ed1f00049becb1", almacen: "5ad36a29d6ed1f00049c1105", stock_url: "http://dev.integra6.ing.puc.cl/api/v1/public/stock", oc_url: "http://dev.integra6.ing.puc.cl/public/oc/" },
                   7 => { id: "5ad36945d6ed1f00049becaa", id_banco: "5ad36945d6ed1f00049becb8", almacen: "5ad36a2ad6ed1f00049c17f3", stock_url: "http://dev.integra7.ing.puc.cl/public/stock", oc_url: "http://dev.integra7.ing.puc.cl/public/oc/" },
                   8 => { id: "5ad36945d6ed1f00049becab", id_banco: "5ad36945d6ed1f00049becb5", almacen: "5ad36a2bd6ed1f00049c2018", stock_url: "http://dev.integra8.ing.puc.cl/public/stock", oc_url: "http://dev.integra8.ing.puc.cl/public/oc/" },
                   9 => { id: "5ad36945d6ed1f00049becac", id_banco: "5ad36945d6ed1f00049becb0", almacen: "5ad36a2cd6ed1f00049c2723", stock_url: "http://dev.integra9.ing.puc.cl/public/stock", oc_url: "http://dev.integra9.ing.puc.cl/public/oc/" }
                 }
=end
  $info_grupos = {  ## production
                   1 => { id: "5aee1697b347e00004615e98", id_banco: "5aee1697b347e00004615ea3", almacen: "5aee16a2b347e00004615eb3", stock_url: "http://integra1.ing.puc.cl/public/stock", oc_url: "http://integra1.ing.puc.cl/public/oc/" },
                   2 => { id: "5aee1697b347e00004615e99", id_banco: "5aee1697b347e00004615ea5", almacen: "5aee16a4b347e00004616831", stock_url: "http://integra2.ing.puc.cl/public/stock", oc_url: "http://integra2.ing.puc.cl/public/oc/" },
                   3 => { id: "5aee1697b347e00004615e9a", id_banco: "5aee1697b347e00004615ea1", almacen: "5aee16a5b347e00004616f80", stock_url: "http://integra3.ing.puc.cl/public/stock", oc_url: "http://integra3.ing.puc.cl/public/oc/" },
                   4 => { id: "5aee1697b347e00004615e9b", id_banco: "5aee1697b347e00004615ea8", almacen: "5aee16a6b347e00004617411", stock_url: "http://integra4.ing.puc.cl/public/stock", oc_url: "http://integra4.ing.puc.cl/public/oc/" },
                   5 => { id: "5aee1697b347e00004615e9c", id_banco: "5aee1697b347e00004615eaa", almacen: "5aee16a8b347e00004617bbc", stock_url: "http://integra5.ing.puc.cl/public/stock", oc_url: "http://integra5.ing.puc.cl/public/oc/" },
                   6 => { id: "5aee1697b347e00004615e9d", id_banco: "5aee1697b347e00004615ea4", almacen: "5aee16a9b347e00004618118", stock_url: "http://integra6.ing.puc.cl/api/v1/public/stock", oc_url: "http://integra6.ing.puc.cl/public/oc/" },
                   7 => { id: "5aee1697b347e00004615e9e", id_banco: "5aee1697b347e00004615ea2", almacen: "5aee16acb347e0000461892f", stock_url: "http://integra7.ing.puc.cl/public/stock", oc_url: "http://integra7.ing.puc.cl/public/oc/" },
                   8 => { id: "5aee1697b347e00004615e9f", id_banco: "5aee1697b347e00004615ea6", almacen: "5aee16aeb347e00004618f3e", stock_url: "http://integra8.ing.puc.cl/public/stock", oc_url: "http://integra8.ing.puc.cl/public/oc/" },
                   9 => { id: "5aee1697b347e00004615ea0", id_banco: "5aee1697b347e00004615eab", almacen: "5aee16afb347e000046195a7", stock_url: "http://integra9.ing.puc.cl/public/stock", oc_url: "http://integra9.ing.puc.cl/public/oc/" }
                 }

end
