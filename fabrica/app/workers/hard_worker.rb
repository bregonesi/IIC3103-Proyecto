class HardWorker
  include Sidekiq::Worker

  def perform
    # Do something
    puts 'do something'
  end
end
