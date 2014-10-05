class WotApiInterface
	def initialize(logger)
		@logger = logger
	end



	def send_query(method_name, params = nil)
		if params.nil?
			method_response = send(method_name)
		else
			method_response = send(method_name, params)
		end

		uri = server + method_response[:name]
		method_response[:params][:application_id] = application_id

		@logger.log('sending request of type ' + method_response[:name].to_s)

		uri = URI(uri)
		uri.query = URI.encode_www_form(method_response[:params])
		response = Net::HTTP.get_response(uri)
		if response.code.to_i != 200
			raise StandardError.new('Perhaps wrong HTTP status? ' + response.code.to_s)
		end
		response_body = JSON.parse(response.body)
		if response_body['status'] == 'error'
			raise StandardError.new('Error ' + response_body['error']['code'].to_s + ': ' + response_body['error']['message'].to_s + '.')
		end

		@logger.log('result of ' + method_response[:name].to_s + ' is ' + response.code)

		response_body
	end













	private

	def application_id
		'642dbb8ed81db4d7e14efce9d7923883'
	end

	def server
		'https://api.worldoftanks.ru/wot/'
	end



	def get_all_clans
		name = 'globalwar/top/'
		params = {map_id: 'globalmap', order_by: 'provinces_count', fields: 'provinces_count,clan_id,members_count,name'}
		{name: name, params: params}
	end

	def get_players_from_clan(clan_id)
		name = 'clan/info/'
		params = {clan_id: clan_id.to_i, fields: 'members.account_id,members.account_name'}
		{name: name, params: params}
	end

	def get_players_tanks(account_ids)
		name = 'account/tanks/'
		params = {account_id: account_ids, fields: 'mark_of_mastery,tank_id'}
		{name: name, params: params}
	end

	def get_tanks_info(tank_ids)
		# TODO: cache it
		name = 'encyclopedia/tankinfo/'
		params = {tank_id: tank_ids, fields: 'gun_damage_min,gun_damage_max,max_health,level'}
		{name: name, params: params}
	end
end
