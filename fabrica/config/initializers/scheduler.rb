require 'rufus-scheduler'

include SchedulerHelper

if defined?(::Rails::Server) || defined?(PhusionPassenger)
	puts "Partiendo scheduler"

	job = Rufus::Scheduler.new(:max_work_threads => 1, :lockfile => ".rufus-scheduler.lock")

	unless job.down?
		job.every '35s' do
			puts "Ejecutando update."

			# Marcamos ordenes vencidas y las finalizadas
			Scheduler::OrderHelper.marcar_vencidas
			Scheduler::OrderHelper.sincronizar_informacion
			Scheduler::OrderHelper.marcar_finalizadas

			# Aca movemos los items de almacen #
			Scheduler::ProductosHelper.hacer_movimientos
			
			# Cargamos nuevos stocks y stock de almacenes nuevos #
			Scheduler::ProductosHelper.cargar_nuevos  ## y elimina los vencidos
			
			# Vemos que ordenes aceptar #
			Scheduler::OrderHelper.aceptar_ordenes

			# Chequeo de si alguna de las aceptadas tiene stock #
			Scheduler::OrderHelper.chequear_si_hay_stock

			# Aca pagamos las ordenes #
			Scheduler::PaymentHelper.pagar_ordenes

			# Aca despachamos lo pagado #
			Scheduler::ShipmentHelper.despachar_ordenes

			# Cambiamos las ordenes de almacen #
			Scheduler::OrderHelper.cambiar_almacen

			# Aca despachamos lo pagado #
			Scheduler::ShipmentHelper.despachar_ordenes

			# Volvemos a sincronizar ya que pudimos haber despachado #
			Scheduler::OrderHelper.sincronizar_informacion
			
			# Fabricamos las pedidas #
			Scheduler::OrderHelper.fabricar_api
			
			# Chequeamos si tenemos nuevos almacenes o nos han eliminado alguno #
			Scheduler::AlmacenesHelper.nuevos_almacenes
			Scheduler::AlmacenesHelper.eliminar_extras

			# Aca movemos los items de almacen #
			Scheduler::ProductosHelper.hacer_movimientos

			# Cargamos nuevos stocks y stock de almacenes nuevos #
			Scheduler::ProductosHelper.cargar_nuevos  ## y elimina los vencidos

			# Tratamos de que se mantenga los optimos de cada almacen #
			Scheduler::AlmacenesHelper.mantener_consistencia

			puts "Termina update."
		end # end del scheduler
	end


  job_sftp = Rufus::Scheduler.new(:max_work_threads => 1)
  job_sftp.every '10m' do
		puts "Ejecutando chequeo de ordenes nuevas ftp"

		# Descargamos nuevas ordenes
		Scheduler::SftpHelper.agregar_nuevas_ordenes

		# agregar chequeo de hook

		puts "Termina chequeo de ordenes nuevas ftp"
  end

end
