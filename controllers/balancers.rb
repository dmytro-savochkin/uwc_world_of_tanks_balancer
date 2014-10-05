require_relative 'base'

class Controllers::Balancers < Controllers::Base
	def get_balanced_teams
		logger = CustomLogger.new
		balancer = Balancer.new(logger)
		balancer.balance
	end
end