module SchedulerHelper
	include Scheduler::PaymentHelper
	include Scheduler::ShipmentHelper
	include Scheduler::OrderHelper
	include Scheduler::AlmacenesHelper
	include Scheduler::ProductosHelper

	include Scheduler::SftpHelper
	include Scheduler::ConstantesHelper

end
