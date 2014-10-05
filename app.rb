require 'sinatra'
require 'sinatra-initializers'
require 'json'
require 'yaml'
require 'haml'
require 'net/http'
require 'sinatra/activerecord'
require 'active_support/all'
require_relative 'models/custom_logger'
require_relative 'models/wot_api_interface'
require_relative 'models/balancer'
require_relative 'controllers/balancers'


configure do
	set :server, 'webrick'
end

get '/' do
	@clan_data, @teams, @players_for_levels = Controllers::Balancers.new.get_balanced_teams
	haml :balanced_teams
end

error do
	'Something goes wrong. ' + env['sinatra.error'].to_s
end

after do
	content_type :html
end





