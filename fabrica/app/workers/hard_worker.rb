class HardWorker
  include Sidekiq::Worker

  def perform(name, count)
    # Do something
    puts 'do something '
  end
end
