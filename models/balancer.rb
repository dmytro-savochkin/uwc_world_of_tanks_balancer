class Balancer
	LEVELS = 4..6
	PLAYERS_COUNT = 15

	PLAYERS_IN_ONE_LOOP = 20



	def initialize(logger)
		@logger = logger
		@api_interface = WotApiInterface.new(logger)
		set_players_for_levels
		@players_ids_queue = []
		@tanks_info = {}
		@players_tanks_global_hash = {}
		initialize_team_levels
	end





	def balance
		clan_members, clan_data = choose_clans

		team1 = []
		team2 = []
		while team1.reject{|e|e.nil?}.length < PLAYERS_COUNT or team2.reject{|e|e.nil?}.length < PLAYERS_COUNT
			clan_members, accounts = get_random_clan_members(clan_members)
			set_tanks_and_their_data_from_api(accounts)
			team1 = add_players_to_team1(team1, accounts)
			team2 = add_players_to_team2(team1, team2, accounts)
		end

		[clan_data, [team1, team2], @players_for_level]
	end











	private


	def choose_clans
		clans = @api_interface.send_query('get_all_clans')
		top_ten_clans = clans['data'][0...10]
		two_random_clans = top_ten_clans.select{|clan| clan['members_count'] > 20}.sample(2)
		clans_data = two_random_clans.map{|clan| {name: clan['name'], id: clan['clan_id']}}

		clans_members = []
		threads = []
		two_random_clans.each do |clan|
			threads << Thread.new do
				members_hash = @api_interface.send_query('get_players_from_clan', clan['clan_id'])['data'][clan['clan_id'].to_s]['members']
				clans_members.push members_hash.to_a.map{|e| e.last}
			end
		end
		threads.map{|t| t.value}

		[clans_members, clans_data]
	end



	def get_random_clan_members(clans_members)
		if clans_members[0].length < PLAYERS_IN_ONE_LOOP or clans_members[1].length < PLAYERS_IN_ONE_LOOP
			raise StandardError.new('Not enough players in clan to balance them. Try again with different clans.')
		end

		accounts = []
		clans_members.each_with_index do |clan_members, index|
			players = clan_members.sample(PLAYERS_IN_ONE_LOOP)
			players_ids = players.map{|player| player['account_id']}
			accounts.push players
			clans_members[index].delete_if do |member|
				players_ids.include? member['account_id"']
			end
		end

		[clans_members, accounts]
	end


	def set_tanks_and_their_data_from_api(accounts)
		@players_ids_queue = accounts.map{|team| team.map{|player| player['account_id']}}
		current_players_tanks = @api_interface.send_query('get_players_tanks', @players_ids_queue.flatten.join(','))['data']
		tank_ids = current_players_tanks.values.map{|tanks| tanks.map{|tank| tank['tank_id'].to_i}}.flatten
		unique_tanks_id = tank_ids.uniq
		@tanks_info.merge!( @api_interface.send_query('get_tanks_info', unique_tanks_id.join(','))['data'] )

		current_players_tanks.keys.each do |player_id|
			@players_tanks_global_hash[player_id] ||= initialize_player_tanks_hash
			current_players_tanks[player_id] = remove_player_tanks_with_inappropriate_levels(current_players_tanks[player_id])
			set_global_player_tanks_hash(player_id, current_players_tanks[player_id])
			sort_players_tanks_by_score(player_id)
			remove_player_if_no_appropriate_tanks(player_id)
		end
	end



	def add_players_to_team1(team1, accounts)
		if team1.count < PLAYERS_COUNT
			while @players_ids_queue[0].length > 0
				team1_player_id = @players_ids_queue[0].shift
				@players_tanks_global_hash[team1_player_id.to_s].each do |current_level, tanks|
					if tanks.count > 0 and @team_levels[0][current_level] < @players_for_level[current_level]
						team1_player_tank = @players_tanks_global_hash[team1_player_id.to_s][current_level].sample
						team1.push({
								id: team1_player_id,
								name: accounts[0].select{|p| p['account_id'].to_i == team1_player_id.to_i}.first['account_name'],
								tank: team1_player_tank
						})
						@team_levels[0][current_level] += 1
						break
					end
				end
				@players_ids_queue[0].delete(team1_player_id)
				break if team1.count == PLAYERS_COUNT
			end
		end

		team1
	end




	def add_players_to_team2(team1, team2, accounts)
		score_margin = 0.01
		if team1.count == PLAYERS_COUNT
			(0...PLAYERS_COUNT).each do |index|
				if team2[index].nil?
					player1_tank = team1[index][:tank]

					team2_player_found = false
					levels = LEVELS.to_a.dup
					levels.delete(player1_tank['level'])
					([player1_tank['level']] + levels.shuffle).each do |team2_current_level|
						break if team2_player_found

						difference_is_good_enough = false
						best_variant = {tank: nil, id: nil, difference: 9999999.9}
						@players_ids_queue[1].each do |queue2_player_id|
							break if difference_is_good_enough
							queue2_player_level_tanks = @players_tanks_global_hash[queue2_player_id.to_s][team2_current_level]
							if queue2_player_level_tanks.length > 0
								queue2_player_level_tanks.each do |tank|
									tank_score = tank['score']
									current_score_difference = (tank_score - player1_tank['score']).abs
									if current_score_difference < best_variant[:difference] and tank['tank_id'] != player1_tank['tank_id']
										best_variant[:id] = queue2_player_id
										best_variant[:tank] = tank
										best_variant[:difference] = current_score_difference
										if current_score_difference < score_margin
											difference_is_good_enough = true
											break
										end
									end
								end
							end
						end

						if best_variant[:id] != nil
							team2_player_tank = best_variant[:tank]
							team2[index] = {
									id: best_variant[:id],
									name: accounts[1].select{|p| p['account_id'].to_i == best_variant[:id]}.first['account_name'],
									tank: team2_player_tank,
									diff: best_variant[:difference]
							}
							@team_levels[1][team2_current_level] += 1
							team2_player_found = true
							@players_ids_queue[1].delete(best_variant[:id])
						end
					end
				end
			end
		end

		team2
	end














	def remove_player_if_no_appropriate_tanks(player_id)
		empty_for_levels = {}
		LEVELS.each do |level|
			empty_for_levels[level] = 1 if @players_tanks_global_hash[player_id][level].empty?
		end
		if empty_for_levels.values.all?
			@players_ids_queue[0].delete(player_id)
			@players_ids_queue[1].delete(player_id)
		end
	end

	def sort_players_tanks_by_score(player_id)
		@players_tanks_global_hash[player_id].each do |level, player_tanks_for_current_level|
			@players_tanks_global_hash[player_id][level] =
					player_tanks_for_current_level.sort_by{|player_tank| player_tank['score'].to_f}.reverse
		end
	end

	def set_global_player_tanks_hash(player_id, player_tanks)
		player_tanks.each_with_index do |player_tank, index|
			tank_id = player_tank['tank_id']
			tank_level = @tanks_info[tank_id.to_s]['level']
			player_tanks[index].merge!(@tanks_info[player_tank['tank_id'].to_s])
			player_tanks[index]['gun_damage_avg'] =
					0.5 * (player_tanks[index]['gun_damage_max'] + player_tanks[index]['gun_damage_min'])
			player_tanks[index]['score'] = calculate_player_tank_score(player_tank)
			@players_tanks_global_hash[player_id][tank_level].push player_tanks[index]
		end
	end

	def initialize_player_tanks_hash
		hash = {}
		LEVELS.each do |level|
			hash[level] = []
		end
		hash
	end

	def initialize_team_levels
		@team_levels = []
		(0..1).each do |team_id|
			@team_levels[team_id] ||= {}
			LEVELS.each do |level|
				@team_levels[team_id][level] = 0
			end
		end
	end

	def remove_player_tanks_with_inappropriate_levels(player_tanks)
		player_tanks.select! do |player_tank|
			tank_id = player_tank['tank_id']
			@tanks_info[tank_id.to_s]['level'] >= LEVELS.to_a.first and @tanks_info[tank_id.to_s]['level'] <= LEVELS.to_a.last
		end
	end

	def set_players_for_levels
		@players_for_level = {}
		LEVELS.each_with_index do |level, i|
			if i == (LEVELS.count - 1)
				@players_for_level[level] = PLAYERS_COUNT - @players_for_level.values.inject(&:+)
			else
				min = (PLAYERS_COUNT/LEVELS.count).floor - (PLAYERS_COUNT/LEVELS.count/2).floor
				max = (PLAYERS_COUNT/LEVELS.count).floor + (PLAYERS_COUNT/LEVELS.count/2).floor
				players_for_this_level = (min..max).to_a.sample
				@players_for_level[level] = players_for_this_level
			end
		end
	end


	def calculate_player_tank_score(player_tank)
		mark_of_mastery_importance = 1.0
		avg_damage_importance = 3.0
		max_health_importance = 2.5

		max_mark_of_mastery = 4
		max_possible_avg_damage = 2250.5 # found experimentally
		max_possible_health = 3000.0 # found experimentally

		normalized_mastery = 1.0 + mark_of_mastery_importance * player_tank['mark_of_mastery'].to_f / max_mark_of_mastery
		normalized_avg_damage = 1.0 + avg_damage_importance * player_tank['gun_damage_avg'].to_f / max_possible_avg_damage
		normalized_max_health = 1.0 + max_health_importance * player_tank['max_health'].to_f / max_possible_health

		normalized_mastery * normalized_avg_damage * normalized_max_health
	end
end
