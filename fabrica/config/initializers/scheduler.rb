require 'rufus-scheduler'
include SchedulerHelper

if defined?(::Rails::Server) || File.basename($0) =='rake'
	puts "Partiendo scheduler"

	job = Rufus::Scheduler.new(:max_work_threads => 1)

	job.every '35s' do
	#job.every '1m' do
	  puts "Ejecutando update."
	  stop_scheduler = false

		# Aca pagamos las ordenes #
		Scheduler::PaymentHelper.pagar_ordenes

		# Aca despachamos lo pagado #
		Scheduler::ShipmentHelper.despachar_ordenes

		# Chequeamos si tenemos nuevos almacenes o nos han eliminado alguno #
		Scheduler::AlmacenesHelper.nuevos_almacenes
		Scheduler::AlmacenesHelper.eliminar_extras

		# Aca movemos los items de almacen #
		Scheduler::ProductosHelper.hacer_movimientos

	  # Cargamos nuevos stocks y stock de almacenes nuevos #
	  Scheduler::ProductosHelper.cargar_nuevos  ## y elimina los vencidos

	  puts "Termina update."
	end # end del scheduler

end