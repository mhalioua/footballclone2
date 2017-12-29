namespace :setup do

	task :daily => :environment do
		day = Time.now
		day_index = day.strftime("%j").to_i
		result = (day_index + 2) / 7 - 35
		week_index = (result < 0) ? (0) : result

		game_link = "nfl"
		(0..1).each do |index|
			Rake::Task["setup:getWeekly"].invoke(2017, game_link, week_index+index)
			Rake::Task["setup:getWeekly"].reenable
			game_link = "college-football"
		end
	end

	task :min => :environment do
		game_day = (Time.now - 5.hours).to_formatted_s(:number)[0..7]

		Rake::Task["setup:getGameState"].invoke(game_day)
		Rake::Task["setup:getGameState"].reenable
		
		Rake::Task["setup:second"].invoke(game_day)
		Rake::Task["setup:second"].reenable

		game_day = (Time.now - 28.hours).to_formatted_s(:number)[0..7]
		Rake::Task["setup:getGameState"].invoke(game_day)
		Rake::Task["setup:getGameState"].reenable
		
		Rake::Task["setup:second"].invoke(game_day)
		Rake::Task["setup:second"].reenable
	end

	task :hourly => :environment do
		Rake::Task["setup:daily"].invoke
		Rake::Task["setup:daily"].reenable

		game_day = (Time.now - 5.hours).to_formatted_s(:number)[0..7]
		Rake::Task["setup:first"].invoke(game_day)
		Rake::Task["setup:first"].reenable
		game_day = (Time.now - 28.hours).to_formatted_s(:number)[0..7]
		Rake::Task["setup:first"].invoke(game_day)
		Rake::Task["setup:first"].reenable
	end

	task :getWeekly, [:year, :game_link, :week_index] => [:environment] do |t, args|
		include Api

		game_link = args[:game_link]
		week_index = args[:week_index]
		year = args[:year]
		game_type = "NFL"
		if game_link == "college-football"
			game_type = "CFB"
		end

		url = "http://www.espn.com/#{game_link}/schedule/_/week/#{week_index}/year/#{year}"
		doc = download_document(url)
		puts url
	  	index = { away_team: 0, home_team: 1, result: 2 }
	  	elements = doc.css("tr")
	  	elements.each do |slice|
	  		if slice.children.size < 6
	  			next
	  		end
	  		away_team = slice.children[index[:away_team]].text
	  		if away_team == "matchup"
	  			next
	  		end
	  		href = slice.children[index[:result]].child['href']
	  		game_id = href[-9..-1]
	  		unless game = Game.find_by(game_id: game_id)
			  	game = Game.create(game_id: game_id)
			end

			if slice.children[index[:home_team]].text == "TBD TBD"
				result 		= "TBD"
				home_team 	= "TBD"
				home_abbr 	= "TBD"
				away_abbr 	= "TBD"
				away_team 	= "TBD"
			else
				if slice.children[index[:home_team]].children[0].children.size == 2
		  			home_team = slice.children[index[:home_team]].children[0].children[1].children[0].text
		  			home_abbr = slice.children[index[:home_team]].children[0].children[1].children[2].text
		  		elsif slice.children[index[:home_team]].children[0].children.size == 3
		  			home_team = slice.children[index[:home_team]].children[0].children[1].children[0].text + slice.children[index[:home_team]].children[0].children[2].children[0].text
		  			home_abbr = slice.children[index[:home_team]].children[0].children[2].children[2].text
		  		elsif slice.children[index[:home_team]].children[0].children.size == 1
		  			home_team = slice.children[index[:home_team]].children[0].children[0].children[0].text
		  			home_abbr = slice.children[index[:home_team]].children[0].children[0].children[2].text
		  		end

		  		if slice.children[index[:away_team]].children.size == 2
	  				away_abbr = slice.children[index[:away_team]].children[1].children[2].text
		  			away_team = slice.children[index[:away_team]].children[1].children[0].text
	  			elsif slice.children[index[:away_team]].children.size == 3
	  				away_abbr = slice.children[index[:away_team]].children[2].children[2].text
	  				away_team = slice.children[index[:away_team]].children[1].text + slice.children[index[:away_team]].children[2].children[0].text
	  			elsif slice.children[index[:away_team]].children.size == 1
	  				away_abbr = slice.children[index[:away_team]].children[0].children[2].text
		  			away_team = slice.children[index[:away_team]].children[0].children[0].text
	  			end
				result = slice.children[index[:result]].text
	  		end

	  		url = "http://www.espn.com/#{game_link}/game?gameId=#{game_id}"
	  		doc = download_document(url)
			puts url
	  		element = doc.css(".game-date-time").first
	  		game_date = element.children[1]['data-date']

	  		game.update(away_team: away_team, home_team: home_team, game_type: game_type, home_abbr: home_abbr, away_abbr: away_abbr, game_date: game_date)
	  	end
	end

	task :getGameState, [:game_day] => [:environment] do |t, args|
		include Api
		game_day = args[:game_day]

  		games = Game.where("game_date between ? and ?", Date.parse(game_day).beginning_of_day, Date.parse(game_day).end_of_day)
		
		games.each do |game|
			game_link = "college-football"
			game_type = game.game_type
			if game_type == "NFL"
				game_link= "nfl"
			end
			game_id = game.game_id

			url = "http://www.espn.com/#{game_link}/matchup?gameId=#{game_id}"
  			doc = download_document(url)
			puts url
  			element = doc.css(".game-time").first
  			game_status = element.text

	  		game_state = 4
	  		if game_status.include?("Canceled") || game_status.include?("TBD") || game_status.include?("Postponed") || game_status.include?("Delayed")
	  			game_state = 6
	  		elsif game_status.include?("Final")
	  			game_state = 5
	  		elsif game_status.include?("4th") || game_status.include?("3rd")
	  			game_state = 3
	  		elsif game_status.include?("Half")
	  			game_state = 0
	  		elsif game_status.include?("2nd")
	  			game_state = 1
	  		elsif game_status.include?("1st")
	  			game_state = 2
	  		end

  			if game_state < 3 || game_state == 5
  				scores = doc.css(".score")
  				away_result = scores[0].text
  				home_result = scores[1].text

				td_elements = doc.css("#gamepackage-matchup td")
				home_team_total 	= ""
				away_team_total 	= ""
				home_team_rushing 	= ""
				away_team_rushing 	= ""
				td_elements.each_slice(3) do |slice|
					if slice[0].text.include?("Total Yards")
						away_team_total = slice[1].text
						home_team_total = slice[2].text
					end
					if slice[0].text.include?("Rushing") && !slice[0].text.include?("Rushing Attempts") && !slice[0].text.include?("Rushing 1st")
						away_team_rushing = slice[1].text
						home_team_rushing = slice[2].text
						break
					end
				end

				url = "http://www.espn.com/#{game_link}/boxscore?gameId=#{game_id}"
		  		doc = download_document(url)
				puts url
		  		element = doc.css("#gamepackage-rushing .gamepackage-home-wrap .highlight td")
		  		home_car 		= ""
		  		home_ave_car 	= ""
		  		home_rush_long 	= ""
		  		if element.size > 5
			  		home_car 		= element[1].text
			  		home_ave_car 	= element[3].text
			  		home_rush_long 	= element[5].text
			  	end

		  		element = doc.css("#gamepackage-rushing .gamepackage-away-wrap .highlight td")
		  		away_car 		= ""
		  		away_ave_car 	= ""
		  		away_rush_long 	= ""
		  		if element.size > 5
			  		away_car 		= element[1].text
			  		away_ave_car 	= element[3].text
			  		away_rush_long 	= element[5].text
			  	end

		  		element = doc.css("#gamepackage-receiving .gamepackage-home-wrap .highlight td")
		  		home_pass_long 	= ""
		  		if element.size > 5
		  			home_pass_long 	= element[5].text
		  		end

		  		element = doc.css("#gamepackage-receiving .gamepackage-away-wrap .highlight td")
		  		away_pass_long 	= ""
		  		if element.size > 5
		  			away_pass_long 	= element[5].text
		  		end

				element = doc.css("#gamepackage-passing .gamepackage-home-wrap .highlight td")
				home_c_att 		= ""
				home_ave_att 	= ""
				home_total_play = ""
				home_play_yard 	= ""

		  		if element.size > 5
					home_c_att 		= element[1].text
					home_ave_att 	= element[3].text

					home_att_index 	= home_c_att.index("/")
					home_total_play = home_car.to_i + home_c_att[home_att_index+1..-1].to_i
					home_play_yard 	= home_team_total.to_f / home_total_play
				end

				element = doc.css("#gamepackage-passing .gamepackage-away-wrap .highlight td")
				away_c_att 		= ""
				away_ave_att 	= ""
				away_total_play = ""
				away_play_yard 	= ""
		  		if element.size > 5
					away_c_att 		= element[1].text
					away_ave_att 	= element[3].text

					away_att_index 	= away_c_att.index("/")
					away_total_play = away_car.to_i + away_c_att[away_att_index+1..-1].to_i
					away_play_yard 	= away_team_total.to_f / away_total_play
				end

				element = doc.css("#gamepackage-defensive .gamepackage-home-wrap .highlight td")
				home_sacks = ""
				if element.size > 3
					home_sacks 		= element[3].text
				end

				element = doc.css("#gamepackage-defensive .gamepackage-away-wrap .highlight td")
				away_sacks = ""
				if element.size > 3
					away_sacks 		= element[3].text
				end


				if game_state == 5
	  				unless score = game.scores.find_by(result: "Final")
					  	score = game.scores.create(result: "Final")
					end
					score.update(game_status: game_status, home_team_total: home_team_total, away_team_total: away_team_total, home_team_rushing: home_team_rushing, away_team_rushing: away_team_rushing, home_result: home_result, away_result: away_result, home_car: home_car, home_ave_car: home_ave_car, home_rush_long: home_rush_long, home_c_att: home_c_att, home_ave_att: home_ave_att, home_total_play: home_total_play, home_play_yard: home_play_yard, home_sacks: home_sacks, away_car: away_car, away_ave_car: away_ave_car, away_rush_long: away_rush_long, away_c_att: away_c_att, away_ave_att: away_ave_att, away_total_play: away_total_play, away_play_yard: away_play_yard, away_sacks: away_sacks, home_pass_long: home_pass_long, away_pass_long: away_pass_long)
				elsif game_state < 3
					unless score = game.scores.find_by(result: "Half")
					  	score = game.scores.create(result: "Half")
					end
					if game_state == 2
						game_status = "1Q"
					elsif game_state == 1
						game_time_index = game_status.index(" ")
						game_status = game_status[0..game_time_index]
						if game_status.index(":") == 1
							game_status = "0" + game_status
						end
					end
					score.update(game_status: game_status, home_team_total: home_team_total, away_team_total: away_team_total, home_team_rushing: home_team_rushing, away_team_rushing: away_team_rushing, home_result: home_result, away_result: away_result, home_car: home_car, home_ave_car: home_ave_car, home_rush_long: home_rush_long, home_c_att: home_c_att, home_ave_att: home_ave_att, home_total_play: home_total_play, home_play_yard: home_play_yard, home_sacks: home_sacks, away_car: away_car, away_ave_car: away_ave_car, away_rush_long: away_rush_long, away_c_att: away_c_att, away_ave_att: away_ave_att, away_total_play: away_total_play, away_play_yard: away_play_yard, away_sacks: away_sacks, home_pass_long: home_pass_long, away_pass_long: away_pass_long)
			   	end
  			end

	  		kicked = game.kicked
	  		first_drive = game.first_drive
	  		second_drive = game.second_drive
	  		if game_state < 3 || game_state == 5
				url = "http://www.espn.com/#{game_link}/playbyplay?gameId=#{game_id}"
				puts url
		  		doc = download_document(url)
		  		away_img = doc.css(".away img")
		  		if away_img.size > 0
		  			away_img = away_img[1]['src'][-20..-1]
		  		else
		  			away_image = "NoImage"
		  		end
		  		check_img = doc.css(".accordion-header img")
		  		if game_state < 3
		  			first_drive = check_img.size
		  		elsif game_state == 5
		  			second_drive = check_img.size
		  			if game.first_drive.to_i == 0
				  		check_img_detail = doc.css(".css-accordion .accordion-item")
				  		check_img_detail.each_with_index do |element, index|
				  			if element.children.size == 3
				  				first_drive = index
				  				break
				  			end
				  		end
		  			end
		  		end
		  		if check_img.size > 0 && away_image != "NoImage"
		  			if game_state < 4
		  				check_img = check_img[check_img.size-1]['src'][-20..-1]
		  			else
		  				check_img = check_img[0]['src'][-20..-1]
		  			end
			  		kicked = "away"
			  		if check_img == away_img
			  			kicked = "home"
			  		end
			  	end
		  	end
		  	if game.game_state == 1 && game_state == 0
		  		game_status = Time.now
		  	elsif game.game_state == 0 && game_state == 0
		  		game_status = game.game_status
		  	end
  			game.update(kicked: kicked, game_state: game_state, game_status: game_status, first_drive: first_drive, second_drive: second_drive)
	  	end
	end

	task :first, [:game_day] => [:environment] do |t, args|

		include Api
		game_day = args[:game_day]
		games = Game.all

		game_link = "college-football"
		(0..1).each do |index|
			puts game_day
			url = "https://www.sportsbookreview.com/betting-odds/#{game_link}/merged/?date=#{game_day}"
			doc = download_document(url)
			elements = doc.css(".event-holder")
			elements.each do |element|
				if element.children[0].children[3].children.size < 3
					next
				end
				if element.children[0].children[5].children.size < 5
					next
				end
				home_number 	= element.children[0].children[3].children[2].text
				away_number 	= element.children[0].children[3].children[1].text
				home_name 		= element.children[0].children[5].children[1].text
				away_name 		= element.children[0].children[5].children[0].text
				home_pinnacle 	= element.children[0].children[9].children[1].text
				away_pinnacle 	= element.children[0].children[9].children[0].text
				ind = home_name.index(") ")
				home_name = ind ? home_name[ind+2..-1] : home_name
				ind = away_name.index(") ")
				away_name = ind ? away_name[ind+2..-1] : away_name
				ind = home_name.index(" (")
				home_name = ind ? home_name[0..ind-1] : home_name
				ind = away_name.index(" (")
				away_name = ind ? away_name[0..ind-1] : away_name
				game_time = element.children[0].children[4].text
				ind = game_time.index(":")
				hour = ind ? game_time[0..ind-1].to_i : 0
				min = ind ? game_time[ind+1..ind+3].to_i : 0
				ap = game_time[-1]
				if ap == "p" && hour != 12
					hour = hour + 12
				end
				if ap == "a" && hour == 12
					hour = 24
				end
				if @nicknames[home_name]
				  home_name = @nicknames[home_name]
				end
				if @nicknames[away_name]
				  away_name = @nicknames[away_name]
				end
				date = Time.new(game_day[0..3], game_day[4..5], game_day[6..7]).change(hour: 0, min: min).in_time_zone('Eastern Time (US & Canada)') + 5.hours +  hour.hours
				matched = games.select{|field| field.home_team.include?(home_name) && field.away_team.include?(away_name) && field.game_date == date }
				if matched.size > 0
					update_game = matched.first
					update_game.update(home_number: home_number, away_number: away_number, home_pinnacle: home_pinnacle, away_pinnacle: away_pinnacle)
				end
				matched = games.select{|field| field.home_team.include?(away_name) && field.away_team.include?(home_name) && field.game_date == date }
				if matched.size > 0
					update_game = matched.first
					update_game.update(home_number: away_number, away_number: home_number, home_pinnacle: away_pinnacle, away_pinnacle:home_pinnacle )
				end
			end
			game_link = "nfl-football"
		end
	end

	task :second, [:game_day] => [:environment] do |t, args|
		include Api

		game_day = args[:game_day]
		games = Game.all

		game_link = "college-football"
		(0..1).each do |index|
			url = "https://www.sportsbookreview.com/betting-odds/#{game_link}/merged/2nd-half/?date=#{game_day}"
			doc = download_document(url)
			puts url
			elements = doc.css(".event-holder")
			elements.each do |element|
				if element.children[0].children[3].children.size < 3
					next
				end
				home_number 		= element.children[0].children[3].children[2].text.to_i
				away_number 		= element.children[0].children[3].children[1].text.to_i
				home_2nd_pinnacle 	= element.children[0].children[9].children[1].text
				away_2nd_pinnacle 	= element.children[0].children[9].children[0].text
				game_time = element.children[0].children[4].text
				ind = game_time.index(":")
				hour = ind ? game_time[0..ind-1].to_i : 0
				min = ind ? game_time[ind+1..ind+3].to_i : 0
				ap = game_time[-1]
				if ap == "p" && hour != 12
					hour = hour + 12
				end
				if ap == "a" && hour == 12
					hour = 24
				end
				date = Time.new(game_day[0..3], game_day[4..5], game_day[6..7]).change(hour: 0, min: min).in_time_zone('Eastern Time (US & Canada)') + 5.hours + hour.hours
				matched = games.select{|field| (field.home_number == home_number && field.away_number == away_number && field.game_date == date) }
				if matched.size > 0
					update_game = matched.first
					update_game.update(home_2nd_pinnacle: home_2nd_pinnacle, away_2nd_pinnacle: away_2nd_pinnacle)
				end
				matched = games.select{|field| (field.home_number == away_number && field.away_number == home_number && field.game_date == date) }
				if matched.size > 0
					update_game = matched.first
					update_game.update(home_2nd_pinnacle: away_2nd_pinnacle , away_2nd_pinnacle: home_2nd_pinnacle)
				end
			end
			game_link = "nfl-football"
		end
	end

	task :tensecond => :environment do
		include Api
	  	games = Game.where(game_state: "1")
	  	puts "10secs - #{games.size}"
			
		games.each do |game|
			game_link = "college-football"
			game_type = game.game_type
			if game_type == "NFL"
				game_link= "nfl"
			end
			game_id = game.game_id

			url = "http://www.espn.com/#{game_link}/matchup?gameId=#{game_id}"
			doc = download_document(url)
			puts url
			element = doc.css(".game-time").first
			game_status = element.text

	  		game_state = 0
	  		if game_status.include?("2nd")
	  			game_state = 1
	  		end

			scores = doc.css(".score")
			away_result = scores[0].text
			home_result = scores[1].text

			td_elements = doc.css("#gamepackage-matchup td")
			home_team_total 	= ""
			away_team_total 	= ""
			home_team_rushing 	= ""
			away_team_rushing 	= ""
			td_elements.each_slice(3) do |slice|
				if slice[0].text.include?("Total Yards")
					away_team_total = slice[1].text
					home_team_total = slice[2].text
				end
				if slice[0].text.include?("Rushing") && !slice[0].text.include?("Rushing Attempts") && !slice[0].text.include?("Rushing 1st")
					away_team_rushing = slice[1].text
					home_team_rushing = slice[2].text
					break
				end
			end

			url = "http://www.espn.com/#{game_link}/boxscore?gameId=#{game_id}"
	  		doc = download_document(url)
			puts url
	  		element = doc.css("#gamepackage-rushing .gamepackage-home-wrap .highlight td")
	  		home_car 		= ""
	  		home_ave_car 	= ""
	  		home_rush_long 	= ""
	  		if element.size > 5
		  		home_car 		= element[1].text
		  		home_ave_car 	= element[3].text
		  		home_rush_long 	= element[5].text
		  	end

	  		element = doc.css("#gamepackage-rushing .gamepackage-away-wrap .highlight td")
	  		away_car 		= ""
	  		away_ave_car 	= ""
	  		away_rush_long 	= ""
	  		if element.size > 5
		  		away_car 		= element[1].text
		  		away_ave_car 	= element[3].text
		  		away_rush_long 	= element[5].text
		  	end

	  		element = doc.css("#gamepackage-receiving .gamepackage-home-wrap .highlight td")
	  		home_pass_long 	= ""
	  		if element.size > 5
	  			home_pass_long 	= element[5].text
	  		end

	  		element = doc.css("#gamepackage-receiving .gamepackage-away-wrap .highlight td")
	  		away_pass_long 	= ""
	  		if element.size > 5
	  			away_pass_long 	= element[5].text
	  		end

			element = doc.css("#gamepackage-passing .gamepackage-home-wrap .highlight td")
			home_c_att 		= ""
			home_ave_att 	= ""
			home_total_play = ""
			home_play_yard 	= ""

	  		if element.size > 5
				home_c_att 		= element[1].text
				home_ave_att 	= element[3].text

				home_att_index 	= home_c_att.index("/")
				home_total_play = home_car.to_i + home_c_att[home_att_index+1..-1].to_i
				home_play_yard 	= home_team_total.to_f / home_total_play
			end

			element = doc.css("#gamepackage-passing .gamepackage-away-wrap .highlight td")
			away_c_att 		= ""
			away_ave_att 	= ""
			away_total_play = ""
			away_play_yard 	= ""
	  		if element.size > 5
				away_c_att 		= element[1].text
				away_ave_att 	= element[3].text

				away_att_index 	= away_c_att.index("/")
				away_total_play = away_car.to_i + away_c_att[away_att_index+1..-1].to_i
				away_play_yard 	= away_team_total.to_f / away_total_play
			end

			element = doc.css("#gamepackage-defensive .gamepackage-home-wrap .highlight td")
			home_sacks = ""
			if element.size > 3
				home_sacks 		= element[3].text
			end

			element = doc.css("#gamepackage-defensive .gamepackage-away-wrap .highlight td")
			away_sacks = ""
			if element.size > 3
				away_sacks 		= element[3].text
			end
		   
			unless score = game.scores.find_by(result: "Half")
			  	score = game.scores.create(result: "Half")
			end

			if game_state == 1
				game_time_index = game_status.index(" ")
				game_status = game_status[0..game_time_index]
				if game_status.index(":") == 1
					game_status = "0" + game_status
				end
			end
			score.update(game_status: game_status, home_team_total: home_team_total, away_team_total: away_team_total, home_team_rushing: home_team_rushing, away_team_rushing: away_team_rushing, home_result: home_result, away_result: away_result, home_car: home_car, home_ave_car: home_ave_car, home_rush_long: home_rush_long, home_c_att: home_c_att, home_ave_att: home_ave_att, home_total_play: home_total_play, home_play_yard: home_play_yard, home_sacks: home_sacks, away_car: away_car, away_ave_car: away_ave_car, away_rush_long: away_rush_long, away_c_att: away_c_att, away_ave_att: away_ave_att, away_total_play: away_total_play, away_play_yard: away_play_yard, away_sacks: away_sacks, home_pass_long: home_pass_long, away_pass_long: away_pass_long)
			
			url = "http://www.espn.com/#{game_link}/playbyplay?gameId=#{game_id}"
	  		doc = download_document(url)
	  		check_img = doc.css(".accordion-header img")
	  		first_drive = check_img.size

		  	if game.game_state == 1 && game_state == 0
		  		game_status = Time.now
		  	end
			game.update(game_state: game_state, game_status: game_status, first_drive: first_drive)
	  	end
	end


	task :all => :environment do
		year = 2009

		(6..15).each do |week_index|
			Rake::Task["setup:previous"].invoke(year, "college-football", week_index)
			Rake::Task["setup:previous"].reenable
		end

		(1..17).each do |week_index|
			Rake::Task["setup:previous"].invoke(year, "nfl", week_index)
			Rake::Task["setup:previous"].reenable
		end


		games = Game.where("game_date between ? and ?", Date.new(year, 1, 1).beginning_of_day, Date.new(year + 1, 1, 1).end_of_day)
	  	game_index = []
		games.each do |game|
			game_index << game.game_date.to_formatted_s(:number)[0..7]
		end
		game_index = game_index.uniq
		game_index = game_index.sort

		game_index.each do |game_day|
			Rake::Task["setup:first"].invoke(game_day)
			Rake::Task["setup:first"].reenable
			
			Rake::Task["setup:second"].invoke(game_day)
			Rake::Task["setup:second"].reenable
		end
	end

	task college: :environment do
		include Api
		game_link="college-football"
		game_id = "292960349"
		
		home_team_passing = 0
		away_team_passing = 0
		home_team_rushing = 0
		away_team_rushing = 0
		home_car = 0
		away_car = 0
		home_attr = 0
		away_attr = 0
		home_rush_long = 0
		away_rush_long = 0
		home_pass_long = 0
  		away_pass_long = 0
  		home_c = 0
  		away_c = 0
  		home_result = 0
  		away_result = 0
  		first_drive = 0
  		second_drive = 0


		url = "http://www.espn.com/#{game_link}/playbyplay?gameId=#{game_id}"
		puts url
  		doc = download_document(url)

  		away_img = doc.css(".away img")
  		if away_img.size > 0
  			away_img = away_img[1]['src'][-20..-1]
  		else
  			away_img = "NoImage"
  		end

  		home_img = doc.css(".home img")
  		if home_img.size > 0
  			home_img = home_img[1]['src'][-20..-1]
  		else
  			home_img = "NoImage"
  		end

  		kicked = 2

  		elements = doc.css(".css-accordion .accordion-item")
  		second_drive = elements.size
  		elements.each_with_index do |element, index|
  			if element.children.length == 3
  				first_drive = index
  				element = elements[index-1]
  				score = element.children[0].children[0].children[1]
  				away_result = score.children[0].children[1].text
  				home_result = score.children[1].children[1].text
  				next
  			end
  			image =  element.children[0].children[0].children[0].children[0]
  			if image.children.size == 0
  				image = "NoImage"
  			else
  				image = image.children[0]['src'][-20..-1]
  			end
  			team_abbr = 0
  			if image == home_img
  				team_abbr = 1
  			elsif image == away_img
  				team_abbr = 0
  			else
  				puts "Image Missing"
  			end

  			if kicked == 2
  				kicked = 1 - team_abbr
  			end

  			lists = element.children[1].children[0].children[0]
  			list_length = (lists.children.length-1)/2
  			(1..list_length).each do |list_index|
  				list = lists.children[list_index*2-1]
  				header = list.children[1].text
  				string = list.children[3].children[1].children[0].text
  				string = string[20..-1].downcase
  				if string.include?("pass complete") && string.exclude?("no play")
  					value = string[/\d+/].to_i
  					if string.include?(" loss ")
  						value = -value
  					end
  					if string.include?("no gain")
  						value = 0
  					end
  					if team_abbr == 1
  						home_attr = home_attr + 1
  						home_c = home_c + 1
  						home_team_passing = home_team_passing + value
  						if value > home_pass_long
  							home_pass_long = value
  						end
  					else
  						away_attr = away_attr + 1
  						away_c = away_c + 1
  						away_team_passing = away_team_passing + value
  						if value > away_pass_long
  							away_pass_long = value
  						end
  					end
  					puts team_abbr
  					puts value
  					puts "pass"
  				end
  				if string.include?("pass incomplete") && string.exclude?("no play")
  					if team_abbr == 1
  						home_attr = home_attr + 1
  					else
  						away_attr = away_attr + 1
  					end
  					puts team_abbr
  					puts "pass incomplete"
  				end

  				if string.include?("pass intercepted") && string.exclude?("no play")
  					if team_abbr == 1
  						home_attr = home_attr + 1
  					else
  						away_attr = away_attr + 1
  					end
  					puts team_abbr
  					puts "pass incomplete"
  				end
  				
  				if string.include?(" pass ") && string.exclude?("no play") && string.exclude?("pass incomplete") && string.exclude?("pass complete") && (string.exclude?("penalty") || string.include?("declined")) && string.exclude?("pass intercepted")
  					value = string[/\d+/].to_i
  					if team_abbr == 1
  						home_attr = home_attr + 1
  						home_c = home_c + 1
  						home_team_passing = home_team_passing + value
  						if value > home_pass_long
  							home_pass_long = value
  						end
  					else
  						away_attr = away_attr + 1
  						away_c = away_c + 1
  						away_team_passing = away_team_passing + value
  						if value > away_pass_long
  							away_pass_long = value
  						end
  					end
  					puts team_abbr
  					puts value
  					puts "pass"
  				end
  				if (string.include?(" run ") || string.include?(" rush ")) && string.exclude?("no play")
  					value = string[/\d+/].to_i
  					if string.include?(" loss ")
  						value = -value
  					end
  					if string.include?("no gain")
  						value = 0
  					end
  					if team_abbr == 1
  						home_car = home_car + 1
  						home_team_rushing = home_team_rushing + value
  						if value > home_rush_long
  							home_rush_long = value
  						end
  					else
  						away_car = away_car + 1
  						away_team_rushing = away_team_rushing + value
  						if value > away_rush_long
  							away_rush_long = value
  						end
  					end
  					puts team_abbr
  					puts value
  					puts "russ"
  				end

  				
  				if string.include?(" sacked ") && string.include?(" loss ") && string.exclude?("no play")
  					value = string[/\d+/].to_i
  					value = -value
  					if team_abbr == 1
  						home_car = home_car + 1
  						home_team_rushing = home_team_rushing + value
  					else
  						away_car = away_car + 1
  						away_team_rushing = away_team_rushing + value
  					end
  					puts team_abbr
  					puts value
  					puts "sacked"
  				end
  			end
  			puts element.children[0].text
  			if element.children[0].text.include?("End of") && first_drive == 0
  				first_drive = index + 1
  				score = element.children[0].children[0].children[1]
  				away_result = score.children[0].children[1].text
  				home_result = score.children[1].children[1].text
  			end
  		end

  		if kicked == 1
  			kicked = "home"
  		elsif kicked == 0
  			kicked = "away"
  		else
  			kicked = ""
  		end

  		home_team_total = home_team_rushing + home_team_passing
  		away_team_total = away_team_rushing + away_team_passing

		home_ave_car = (home_team_rushing.to_f / home_car).round(2)
		away_ave_car = (away_team_rushing.to_f / away_car).round(2)

		home_c_att = home_c.to_s + "/" + home_attr.to_s
		away_c_att = away_c.to_s + "/" + away_attr.to_s

		home_ave_att = (home_team_passing.to_f / home_attr).round(2)
		away_ave_att = (away_team_passing.to_f / away_attr).round(2)

		home_total_play = home_car + home_attr
		home_play_yard 	= home_team_total.to_f / home_total_play

		away_total_play = away_car + away_attr
		away_play_yard 	= away_team_total.to_f / away_total_play

  		puts home_team_passing
		puts away_team_passing
		puts home_team_rushing
		puts away_team_rushing
  		puts home_car
  		puts away_car
  		puts home_c
  		puts away_c
  		puts home_attr
  		puts away_attr
  		puts first_drive
  		puts second_drive
  		puts home_ave_car
  		puts away_ave_car
  		puts home_c_att
  		puts away_c_att
  		puts home_ave_att
  		puts away_ave_att
  		puts home_total_play
  		puts away_total_play
	end

	task nfl: :environment do
		include Api
		game_link="nfl"
		game_id = "301024003"
		
		home_team_passing = 0
		away_team_passing = 0
		home_team_rushing = 0
		away_team_rushing = 0
		home_car = 0
		away_car = 0
		home_attr = 0
		away_attr = 0
		home_rush_long = 0
		away_rush_long = 0
		home_pass_long = 0
  		away_pass_long = 0
  		home_c = 0
  		away_c = 0
  		home_result = 0
  		away_result = 0
  		first_drive = 0
  		second_drive = 0


		url = "http://www.espn.com/#{game_link}/playbyplay?gameId=#{game_id}"
		puts url
  		doc = download_document(url)

  		away_img = doc.css(".away img")
  		if away_img.size > 0
  			away_img = away_img[1]['src'][-20..-1]
  		else
  			away_img = "NoImage"
  		end

  		home_img = doc.css(".home img")
  		if home_img.size > 0
  			home_img = home_img[1]['src'][-20..-1]
  		else
  			home_img = "NoImage"
  		end

  		kicked = 2

  		elements = doc.css(".css-accordion .accordion-item")
  		second_drive = elements.size
  		elements.each_with_index do |element, index|
  			if element.children.length == 3
  				first_drive = index
  				element = elements[index-1]
  				score = element.children[0].children[0].children[1]
  				away_result = score.children[0].children[1].text
  				home_result = score.children[1].children[1].text
  				next
  			end
  			image =  element.children[0].children[0].children[0].children[0]
  			if image.children.size == 0
  				image = "NoImage"
  			else
  				image = image.children[0]['src'][-20..-1]
  			end
  			team_abbr = 0
  			if image == home_img
  				team_abbr = 1
  			elsif image == away_img
  				team_abbr = 0
  			else
  				puts "Image Missing"
  			end

  			if kicked == 2
  				kicked = 1 - team_abbr
  			end

  			lists = element.children[1].children[0].children[0]
  			list_length = (lists.children.length-1)/2
  			(1..list_length).each do |list_index|
  				list = lists.children[list_index*2-1]
  				header = list.children[1].text.downcase
  				string = list.children[3].children[1].children[0].text
  				string = string[25..-1].downcase
  				if (string.include?("pass complete ") || string.include?("pass short") || string.include?("pass deep")) && string.exclude?("no play") && string.exclude?("intercepted")  && string.exclude?("safety") && string.exclude?("attempt")
  					if (string.exclude?("penalty") ||  string.exclude?("enforced"))
	  					if string.include?("no gain") || string.include?("incomplete")
	  						value = 0
	  					else
	  						value_end_index = string.index('yard')
		  					value_start_index = string.rindex(' ', value_end_index-2)
		  					value = string[value_start_index..value_end_index].to_i
		  					if string.include?(" loss ")
		  						value = -value
		  					end
	  					end
	  				else
	  					value_end_index = string.rindex(/\d+/)
	  					value_start_index = string.rindex(' ', value_end_index-2)
	  					value = string[value_start_index..value_end_index].to_i
	  					abbr_end_index = value_start_index - 1
	  					abbr_start_index = string.rindex(' ', abbr_end_index-2)
	  					header_value = header.scan(/\d+/).last.to_i
	  					if header.include?(string[abbr_start_index..abbr_end_index])
	  						value = header_value - value
	  						if value < 0
	  							value = -value
	  						end
	  					else
	  						value = 100 - value - header_value
	  					end
	  				end
  					if team_abbr == 1
  						home_attr = home_attr + 1
  						home_c = home_c + 1
  						home_team_passing = home_team_passing + value
  						if value > home_pass_long
  							home_pass_long = value
  						end
  					else
  						away_attr = away_attr + 1
  						away_c = away_c + 1
  						away_team_passing = away_team_passing + value
  						if value > away_pass_long
  							away_pass_long = value
  						end
  					end
  					puts team_abbr
  					puts value
  					puts "pass"

  				elsif string.include?("sacked at") && string.exclude?("no play") && string.exclude?("intercepted") && string.exclude?("safety") && string.exclude?("attempt")
  					if (string.exclude?("penalty") ||  string.exclude?("enforced"))
	  					if string.include?("no gain")
	  						value = 0
	  					else
	  						value_end_index = string.index('yard')
		  					value_start_index = string.rindex(' ', value_end_index-2)
		  					value = string[value_start_index..value_end_index].to_i
		  					if string.include?(" loss ")
		  						value = -value
		  					end
	  					end
	  				else
	  					value_end_index = string.rindex(/\d+/)
	  					value_start_index = string.rindex(' ', value_end_index-2)
	  					value = string[value_start_index..value_end_index].to_i
	  					abbr_end_index = value_start_index - 1
	  					abbr_start_index = string.rindex(' ', abbr_end_index-2)
	  					header_value = header.scan(/\d+/).last.to_i
	  					if header.include?(string[abbr_start_index..abbr_end_index])
	  						value = header_value - value
	  						if value < 0
	  							value = -value
	  						end
	  					else
	  						value = 100 - value - header_value
	  					end
	  				end
  					if team_abbr == 1
  						home_attr = home_attr + 1
  						home_c = home_c + 1
  						home_team_passing = home_team_passing + value
  						if value > home_pass_long
  							home_pass_long = value
  						end
  					else
  						away_attr = away_attr + 1
  						away_c = away_c + 1
  						away_team_passing = away_team_passing + value
  						if value > away_pass_long
  							away_pass_long = value
  						end
  					end
  					puts team_abbr
  					puts value
  					puts "sacked at"

  				elsif string.include?("pass incomplete") && string.exclude?("no play") && string.exclude?("intercepted") && string.exclude?("safety") && string.exclude?("attempt")
  					if team_abbr == 1
  						home_attr = home_attr + 1
  					else
  						away_attr = away_attr + 1
  					end
  					puts team_abbr
  					puts "pass incomplete"

  				elsif string.include?("pass from") && string.exclude?("no play") && string.exclude?("intercepted") && string.exclude?("safety") && string.exclude?("attempt")
  					if (string.exclude?("penalty") ||  string.exclude?("enforced"))
	  					if string.include?("no gain")
	  						value = 0
	  					else
	  						value_end_index = string.index('yrd')
	  						if !value_end_index
	  							value_end_index = string.index('yd')
	  						end
	  						if !value_end_index
	  							value_end_index = string.index('yard')
	  						end
		  					value_start_index = string.rindex(' ', value_end_index-2)
		  					value = string[value_start_index..value_end_index].to_i
		  					if string.include?(" loss ")
		  						value = -value
		  					end
	  					end
	  				else
	  					value_end_index = string.rindex(/\d+/)
	  					value_start_index = string.rindex(' ', value_end_index-2)
	  					value = string[value_start_index..value_end_index].to_i
	  					abbr_end_index = value_start_index - 1
	  					abbr_start_index = string.rindex(' ', abbr_end_index-2)
	  					header_value = header.scan(/\d+/).last.to_i
	  					if header.include?(string[abbr_start_index..abbr_end_index])
	  						value = header_value - value
	  						if value < 0
	  							value = -value
	  						end
	  					else
	  						value = 100 - value - header_value
	  					end
	  				end
  					if team_abbr == 1
  						home_attr = home_attr + 1
  						home_c = home_c + 1
  						home_team_passing = home_team_passing + value
  						if value > home_pass_long
  							home_pass_long = value
  						end
  					else
  						away_attr = away_attr + 1
  						away_c = away_c + 1
  						away_team_passing = away_team_passing + value
  						if value > away_pass_long
  							away_pass_long = value
  						end
  					end
  					puts team_abbr
  					puts value
  					puts "pass"

  				elsif ( string.include?("right tackle") || string.include?("right guard") || string.include?("left tackle") || string.include?("left guard") || string.include?("up the middle to") || string.include?("right end") || string.include?("left end"))&& string.exclude?("no play") && string.exclude?("safety") && string.exclude?("attempt")
  					if (string.exclude?("penalty") ||  string.exclude?("enforced"))
	  					if string.include?("no gain")
	  						value = 0
	  					else
	  						value_end_index = string.index('yard')
	  						puts value_end_index
		  					value_start_index = string.rindex(' ', value_end_index-2)
		  					puts value_start_index
		  					value = string[value_start_index..value_end_index].to_i
		  					if string.include?(" loss ")
		  						value = -value
		  					end
	  					end
	  				else
	  					value_end_index = string.rindex(/\d+/)
	  					value_start_index = string.rindex(' ', value_end_index-2)
	  					value = string[value_start_index..value_end_index].to_i
	  					abbr_end_index = value_start_index - 1
	  					abbr_start_index = string.rindex(' ', abbr_end_index-2)
	  					header_value = header.scan(/\d+/).last.to_i
	  					if header.include?(string[abbr_start_index..abbr_end_index])
	  						value = header_value - value
	  						if value < 0
	  							value = -value
	  						end
	  					else
	  						value = 100 - value - header_value
	  					end
	  				end

  					if team_abbr == 1
  						home_car = home_car + 1
  						home_team_rushing = home_team_rushing + value
  						if value > home_rush_long
  							home_rush_long = value
  						end
  					else
  						away_car = away_car + 1
  						away_team_rushing = away_team_rushing + value
  						if value > away_rush_long
  							away_rush_long = value
  						end
  					end
  					puts team_abbr
  					puts value
  					puts "russ"
  				end
  			end
  			if element.children[0].text.include?("End of") && first_drive == 0
  				first_drive = index + 1
  				score = element.children[0].children[0].children[1]
  				away_result = score.children[0].children[1].text
  				home_result = score.children[1].children[1].text
  			end
  		end

  		if kicked == 1
  			kicked = "home"
  		elsif kicked == 0
  			kicked = "away"
  		else
  			kicked = ""
  		end

  		home_team_total = home_team_rushing + home_team_passing
  		away_team_total = away_team_rushing + away_team_passing

		home_ave_car = (home_team_rushing.to_f / home_car).round(2)
		away_ave_car = (away_team_rushing.to_f / away_car).round(2)

		home_c_att = home_c.to_s + "/" + home_attr.to_s
		away_c_att = away_c.to_s + "/" + away_attr.to_s

		home_ave_att = (home_team_passing.to_f / home_attr).round(2)
		away_ave_att = (away_team_passing.to_f / away_attr).round(2)

		home_total_play = home_car + home_attr
		home_play_yard 	= home_team_total.to_f / home_total_play

		away_total_play = away_car + away_attr
		away_play_yard 	= away_team_total.to_f / away_total_play

  		puts home_team_passing
		puts away_team_passing
		puts home_team_rushing
		puts away_team_rushing
  		puts home_car
  		puts away_car
  		puts home_c
  		puts away_c
  		puts home_attr
  		puts away_attr
  		puts first_drive
  		puts second_drive
  		puts home_ave_car
  		puts away_ave_car
  		puts home_c_att
  		puts away_c_att
  		puts home_ave_att
  		puts away_ave_att
  		puts home_total_play
  		puts away_total_play
	end

	task :previous, [:year, :game_link, :week_index] => [:environment] do |t, args|
		include Api

		game_link = args[:game_link]
		week_index = args[:week_index]
		year = args[:year]
		game_type = "NFL"
		if game_link == "college-football"
			game_type = "CFB"
		end

		url = "http://www.espn.com/#{game_link}/schedule/_/week/#{week_index}/year/#{year}"
		doc = download_document(url)
		puts url
	  	index = { away_team: 0, home_team: 1, result: 2 }
	  	elements = doc.css("tr")
	  	elements.each do |slice|
	  		if slice.children.size < 6
	  			next
	  		end
	  		away_team = slice.children[index[:away_team]].text
	  		if away_team == "matchup"
	  			next
	  		end
	  		href = slice.children[index[:result]].child['href']
	  		game_id = href[-9..-1]
	  		unless game = Game.find_by(game_id: game_id)
			  	game = Game.create(game_id: game_id)
			end

			url = "http://www.espn.com/#{game_link}/matchup?gameId=#{game_id}"
  			doc = download_document(url)
			puts url
  			element = doc.css(".game-time").first
  			game_status = element.text

			if slice.children[index[:home_team]].text == "TBD TBD"
				result 		= "TBD"
				home_team 	= "TBD"
				home_abbr 	= "TBD"
				away_abbr 	= "TBD"
				away_team 	= "TBD"
			else
				if slice.children[index[:home_team]].children[0].children.size == 2
		  			home_team = slice.children[index[:home_team]].children[0].children[1].children[0].text
		  			home_abbr = slice.children[index[:home_team]].children[0].children[1].children[2].text
		  		elsif slice.children[index[:home_team]].children[0].children.size == 3
		  			home_team = slice.children[index[:home_team]].children[0].children[1].children[0].text + slice.children[index[:home_team]].children[0].children[2].children[0].text
		  			home_abbr = slice.children[index[:home_team]].children[0].children[2].children[2].text
		  		elsif slice.children[index[:home_team]].children[0].children.size == 1
		  			home_team = slice.children[index[:home_team]].children[0].children[0].children[0].text
		  			home_abbr = slice.children[index[:home_team]].children[0].children[0].children[2].text
		  		end

		  		if slice.children[index[:away_team]].children.size == 2
	  				away_abbr = slice.children[index[:away_team]].children[1].children[2].text
		  			away_team = slice.children[index[:away_team]].children[1].children[0].text
	  			elsif slice.children[index[:away_team]].children.size == 3
	  				away_abbr = slice.children[index[:away_team]].children[2].children[2].text
	  				away_team = slice.children[index[:away_team]].children[1].text + slice.children[index[:away_team]].children[2].children[0].text
	  			elsif slice.children[index[:away_team]].children.size == 1
	  				away_abbr = slice.children[index[:away_team]].children[0].children[2].text
		  			away_team = slice.children[index[:away_team]].children[0].children[0].text
	  			end
				result = slice.children[index[:result]].text
	  		end
	  		game_state = 6
	  		if game_status.include?("Final")
	  			game_state = 5
  				scores = doc.css(".score")
  				away_result = scores[0].text
  				home_result = scores[1].text

				td_elements = doc.css("#gamepackage-matchup td")
				home_team_total 	= ""
				away_team_total 	= ""
				home_team_rushing 	= ""
				away_team_rushing 	= ""
				td_elements.each_slice(3) do |slice|
					if slice[0].text.include?("Total Yards")
						away_team_total = slice[1].text
						home_team_total = slice[2].text
					end
					if slice[0].text.include?("Rushing") && !slice[0].text.include?("Rushing Attempts") && !slice[0].text.include?("Rushing 1st")
						away_team_rushing = slice[1].text
						home_team_rushing = slice[2].text
						break
					end
				end

				url = "http://www.espn.com/#{game_link}/boxscore?gameId=#{game_id}"
		  		doc = download_document(url)
				puts url
		  		element = doc.css("#gamepackage-rushing .gamepackage-home-wrap .highlight td")
		  		home_car 		= ""
		  		home_ave_car 	= ""
		  		home_rush_long 	= ""
		  		if element.size > 5
			  		home_car 		= element[1].text
			  		home_ave_car 	= element[3].text
			  		home_rush_long 	= element[5].text
			  	end

		  		element = doc.css("#gamepackage-rushing .gamepackage-away-wrap .highlight td")
		  		away_car 		= ""
		  		away_ave_car 	= ""
		  		away_rush_long 	= ""
		  		if element.size > 5
			  		away_car 		= element[1].text
			  		away_ave_car 	= element[3].text
			  		away_rush_long 	= element[5].text
			  	end

		  		element = doc.css("#gamepackage-receiving .gamepackage-home-wrap .highlight td")
		  		home_pass_long 	= ""
		  		if element.size > 5
		  			home_pass_long 	= element[5].text
		  		end

		  		element = doc.css("#gamepackage-receiving .gamepackage-away-wrap .highlight td")
		  		away_pass_long 	= ""
		  		if element.size > 5
		  			away_pass_long 	= element[5].text
		  		end

				element = doc.css("#gamepackage-passing .gamepackage-home-wrap .highlight td")
				home_c_att 		= ""
				home_ave_att 	= ""
				home_total_play = ""
				home_play_yard 	= ""

		  		if element.size > 5
					home_c_att 		= element[1].text
					home_ave_att 	= element[3].text

					home_att_index 	= home_c_att.index("/")
					home_total_play = home_car.to_i + home_c_att[home_att_index+1..-1].to_i
					home_play_yard 	= home_team_total.to_f / home_total_play
				end

				element = doc.css("#gamepackage-passing .gamepackage-away-wrap .highlight td")
				away_c_att 		= ""
				away_ave_att 	= ""
				away_total_play = ""
				away_play_yard 	= ""
		  		if element.size > 5
					away_c_att 		= element[1].text
					away_ave_att 	= element[3].text

					away_att_index 	= away_c_att.index("/")
					away_total_play = away_car.to_i + away_c_att[away_att_index+1..-1].to_i
					away_play_yard 	= away_team_total.to_f / away_total_play
				end

				element = doc.css("#gamepackage-defensive .gamepackage-home-wrap .highlight td")
				home_sacks = ""
				if element.size > 3
					home_sacks 		= element[3].text
				end

				element = doc.css("#gamepackage-defensive .gamepackage-away-wrap .highlight td")
				away_sacks = ""
				if element.size > 3
					away_sacks 		= element[3].text
				end
			   
				unless score = game.scores.find_by(result: "Final")
				  	score = game.scores.create(result: "Final")
				end

				if game_state == 1
					game_time_index = game_status.index(" ")
					game_status = game_status[0..game_time_index]
					if game_status.index(":") == 1
						game_status = "0" + game_status
					end
				end
				score.update(game_status: game_status, home_team_total: home_team_total, away_team_total: away_team_total, home_team_rushing: home_team_rushing, away_team_rushing: away_team_rushing, home_result: home_result, away_result: away_result, home_car: home_car, home_ave_car: home_ave_car, home_rush_long: home_rush_long, home_c_att: home_c_att, home_ave_att: home_ave_att, home_total_play: home_total_play, home_play_yard: home_play_yard, home_sacks: home_sacks, away_car: away_car, away_ave_car: away_ave_car, away_rush_long: away_rush_long, away_c_att: away_c_att, away_ave_att: away_ave_att, away_total_play: away_total_play, away_play_yard: away_play_yard, away_sacks: away_sacks, home_pass_long: home_pass_long, away_pass_long: away_pass_long)
				
				home_team_passing = 0
				away_team_passing = 0
				home_team_rushing = 0
				away_team_rushing = 0
				home_car = 0
				away_car = 0
				home_attr = 0
				away_attr = 0
				home_rush_long = 0
				away_rush_long = 0
				home_pass_long = 0
		  		away_pass_long = 0
		  		home_c = 0
		  		away_c = 0
		  		home_result = 0
		  		away_result = 0
		  		first_drive = 0
		  		second_drive = 0


				url = "http://www.espn.com/#{game_link}/playbyplay?gameId=#{game_id}"
				puts url
		  		doc = download_document(url)

		  		away_img = doc.css(".away img")
		  		if away_img.size > 0
		  			away_img = away_img[1]['src'][-20..-1]
		  		else
		  			away_img = "NoImage"
		  		end

		  		home_img = doc.css(".home img")
		  		if home_img.size > 0
		  			home_img = home_img[1]['src'][-20..-1]
		  		else
		  			home_img = "NoImage"
		  		end

		  		kicked = 2

		  		elements = doc.css(".css-accordion .accordion-item")
		  		second_drive = elements.size
		  		elements.each_with_index do |element, index|
		  			if element.children.length == 3
		  				first_drive = index
		  				element = elements[index-1]
		  				score = element.children[0].children[0].children[1]
		  				away_result = score.children[0].children[1].text
		  				home_result = score.children[1].children[1].text
		  				break
		  			end
		  			image =  element.children[0].children[0].children[0].children[0]
		  			if image.children.size == 0
		  				image = "NoImage"
		  			else
		  				image = image.children[0]['src'][-20..-1]
		  			end
		  			team_abbr = 0
		  			if image == home_img
		  				team_abbr = 1
		  			elsif image == away_img
		  				team_abbr = 0
		  			else
		  				puts "Image Missing"
		  			end

		  			if kicked == 2
		  				kicked = 1- team_abbr
		  			end

		  			lists = element.children[1].children[0].children[0]
		  			list_length = (lists.children.length-1)/2
		  			(1..list_length).each do |list_index|
		  				list = lists.children[list_index*2-1]
		  				header = list.children[1].text.downcase
		  				string = list.children[3].children[1].children[0].text
		  				string = string[25..-1].downcase
		  				if game_link == "college-football"
			  				if string.include?("pass complete") && string.exclude?("no play")
			  					value = string[/\d+/].to_i
			  					if string.include?(" loss ")
			  						value = -value
			  					end
			  					if string.include?("no gain")
			  						value = 0
			  					end
			  					if team_abbr == 1
			  						home_attr = home_attr + 1
			  						home_c = home_c + 1
			  						home_team_passing = home_team_passing + value
			  						if value > home_pass_long
			  							home_pass_long = value
			  						end
			  					else
			  						away_attr = away_attr + 1
			  						away_c = away_c + 1
			  						away_team_passing = away_team_passing + value
			  						if value > away_pass_long
			  							away_pass_long = value
			  						end
			  					end
			  				end
			  				if string.include?("pass incomplete") && string.exclude?("no play")
			  					if team_abbr == 1
			  						home_attr = home_attr + 1
			  					else
			  						away_attr = away_attr + 1
			  					end
			  				end

			  				if string.include?("pass intercepted") && string.exclude?("no play")
			  					if team_abbr == 1
			  						home_attr = home_attr + 1
			  					else
			  						away_attr = away_attr + 1
			  					end
			  				end
			  				
			  				if string.include?(" pass ") && string.exclude?("no play") && string.exclude?("pass incomplete") && string.exclude?("pass complete") && (string.exclude?("penalty") || string.include?("declined")) && string.exclude?("pass intercepted")
			  					value = string[/\d+/].to_i
			  					if team_abbr == 1
			  						home_attr = home_attr + 1
			  						home_c = home_c + 1
			  						home_team_passing = home_team_passing + value
			  						if value > home_pass_long
			  							home_pass_long = value
			  						end
			  					else
			  						away_attr = away_attr + 1
			  						away_c = away_c + 1
			  						away_team_passing = away_team_passing + value
			  						if value > away_pass_long
			  							away_pass_long = value
			  						end
			  					end
			  				end
			  				if (string.include?(" run ") || string.include?(" rush ")) && string.exclude?("no play")
			  					value = string[/\d+/].to_i
			  					if string.include?(" loss ")
			  						value = -value
			  					end
			  					if string.include?("no gain")
			  						value = 0
			  					end
			  					if team_abbr == 1
			  						home_car = home_car + 1
			  						home_team_rushing = home_team_rushing + value
			  						if value > home_rush_long
			  							home_rush_long = value
			  						end
			  					else
			  						away_car = away_car + 1
			  						away_team_rushing = away_team_rushing + value
			  						if value > away_rush_long
			  							away_rush_long = value
			  						end
			  					end
			  				end

			  				
			  				if string.include?(" sacked ") && string.include?(" loss ") && string.exclude?("no play")
			  					value = string[/\d+/].to_i
			  					value = -value
			  					if team_abbr == 1
			  						home_car = home_car + 1
			  						home_team_rushing = home_team_rushing + value
			  					else
			  						away_car = away_car + 1
			  						away_team_rushing = away_team_rushing + value
			  					end
			  				end
			  			else
			  				if (string.include?("pass complete ") || string.include?("pass short") || string.include?("pass deep")) && string.exclude?("no play") && string.exclude?("intercepted") && string.exclude?("safety") && string.exclude?("attempt")
			  					if (string.exclude?("penalty") ||  string.exclude?("enforced"))
				  					if string.include?("no gain") || string.include?("incomplete")
				  						value = 0
				  					else
				  						value_end_index = string.index('yard')
					  					value_start_index = string.rindex(' ', value_end_index-2)
					  					value = string[value_start_index..value_end_index].to_i
					  					if string.include?(" loss ")
					  						value = -value
					  					end
				  					end
				  				else
				  					value_end_index = string.rindex(/\d+/)
				  					value_start_index = string.rindex(' ', value_end_index-2)
				  					value = string[value_start_index..value_end_index].to_i
				  					abbr_end_index = value_start_index - 1
				  					abbr_start_index = string.rindex(' ', abbr_end_index-2)
				  					header_value = header.scan(/\d+/).last.to_i
				  					if header.include?(string[abbr_start_index..abbr_end_index])
				  						value = header_value - value
				  						if value < 0
				  							value = -value
				  						end
				  					else
				  						value = 100 - value - header_value
				  					end
				  				end
			  					if team_abbr == 1
			  						home_attr = home_attr + 1
			  						home_c = home_c + 1
			  						home_team_passing = home_team_passing + value
			  						if value > home_pass_long
			  							home_pass_long = value
			  						end
			  					else
			  						away_attr = away_attr + 1
			  						away_c = away_c + 1
			  						away_team_passing = away_team_passing + value
			  						if value > away_pass_long
			  							away_pass_long = value
			  						end
			  					end
			  				

			  				elsif string.include?("sacked at") && string.exclude?("no play") && string.exclude?("intercepted") && string.exclude?("safety") && string.exclude?("attempt")
			  					if (string.exclude?("penalty") ||  string.exclude?("enforced"))
				  					if string.include?("no gain")
				  						value = 0
				  					else
				  						value_end_index = string.index('yard')
					  					value_start_index = string.rindex(' ', value_end_index-2)
					  					value = string[value_start_index..value_end_index].to_i
					  					if string.include?(" loss ")
					  						value = -value
					  					end
				  					end
				  				else
				  					value_end_index = string.rindex(/\d+/)
				  					value_start_index = string.rindex(' ', value_end_index-2)
				  					value = string[value_start_index..value_end_index].to_i
				  					abbr_end_index = value_start_index - 1
				  					abbr_start_index = string.rindex(' ', abbr_end_index-2)
				  					header_value = header.scan(/\d+/).last.to_i
				  					if header.include?(string[abbr_start_index..abbr_end_index])
				  						value = header_value - value
				  						if value < 0
				  							value = -value
				  						end
				  					else
				  						value = 100 - value - header_value
				  					end
				  				end
			  					if team_abbr == 1
			  						home_attr = home_attr + 1
			  						home_c = home_c + 1
			  						home_team_passing = home_team_passing + value
			  						if value > home_pass_long
			  							home_pass_long = value
			  						end
			  					else
			  						away_attr = away_attr + 1
			  						away_c = away_c + 1
			  						away_team_passing = away_team_passing + value
			  						if value > away_pass_long
			  							away_pass_long = value
			  						end
			  					end
			  				

			  				elsif string.include?("pass incomplete") && string.exclude?("no play") && string.exclude?("intercepted") && string.exclude?("safety") && string.exclude?("attempt")
			  					if team_abbr == 1
			  						home_attr = home_attr + 1
			  					else
			  						away_attr = away_attr + 1
			  					end
			  				
			  				elsif string.include?("pass from") && string.exclude?("no play") && string.exclude?("intercepted") && string.exclude?("safety") && string.exclude?("attempt")
			  					if (string.exclude?("penalty") ||  string.exclude?("enforced"))
				  					if string.include?("no gain")
				  						value = 0
				  					else
				  						value_end_index = string.index('yrd')
				  						if !value_end_index
				  							value_end_index = string.index('yd')
				  						end
				  						if !value_end_index
				  							value_end_index = string.index('yard')
				  						end
					  					value_start_index = string.rindex(' ', value_end_index-2)
					  					value = string[value_start_index..value_end_index].to_i
					  					if string.include?(" loss ")
					  						value = -value
					  					end
				  					end
				  				else
				  					value_end_index = string.rindex(/\d+/)
				  					value_start_index = string.rindex(' ', value_end_index-2)
				  					value = string[value_start_index..value_end_index].to_i
				  					abbr_end_index = value_start_index - 1
				  					abbr_start_index = string.rindex(' ', abbr_end_index-2)
				  					header_value = header.scan(/\d+/).last.to_i
				  					if header.include?(string[abbr_start_index..abbr_end_index])
				  						value = header_value - value
				  						if value < 0
				  							value = -value
				  						end
				  					else
				  						value = 100 - value - header_value
				  					end
				  				end
			  					if team_abbr == 1
			  						home_attr = home_attr + 1
			  						home_c = home_c + 1
			  						home_team_passing = home_team_passing + value
			  						if value > home_pass_long
			  							home_pass_long = value
			  						end
			  					else
			  						away_attr = away_attr + 1
			  						away_c = away_c + 1
			  						away_team_passing = away_team_passing + value
			  						if value > away_pass_long
			  							away_pass_long = value
			  						end
			  					end
			  				

			  				elsif ( string.include?("right tackle") || string.include?("right guard") || string.include?("left tackle") || string.include?("left guard") || string.include?("up the middle to") || string.include?("right end") || string.include?("left end"))&& string.exclude?("no play") && string.exclude?("safety") && string.exclude?("attempt")
			  					if (string.exclude?("penalty") ||  string.exclude?("enforced"))
				  					if string.include?("no gain")
				  						value = 0
				  					else
				  						value_end_index = string.index('yard')
					  					value_start_index = string.rindex(' ', value_end_index-2)
					  					value = string[value_start_index..value_end_index].to_i
					  					if string.include?(" loss ")
					  						value = -value
					  					end
				  					end
				  				else
				  					value_end_index = string.rindex(/\d+/)
				  					value_start_index = string.rindex(' ', value_end_index-2)
				  					value = string[value_start_index..value_end_index].to_i
				  					abbr_end_index = value_start_index - 1
				  					abbr_start_index = string.rindex(' ', abbr_end_index-2)
				  					header_value = header.scan(/\d+/).last.to_i
				  					if header.include?(string[abbr_start_index..abbr_end_index])
				  						value = header_value - value
				  						if value < 0
				  							value = -value
				  						end
				  					else
				  						value = 100 - value - header_value
				  					end
				  				end

			  					if team_abbr == 1
			  						home_car = home_car + 1
			  						home_team_rushing = home_team_rushing + value
			  						if value > home_rush_long
			  							home_rush_long = value
			  						end
			  					else
			  						away_car = away_car + 1
			  						away_team_rushing = away_team_rushing + value
			  						if value > away_rush_long
			  							away_rush_long = value
			  						end
			  					end
			  				end
			  			end
		  			end

		  			if element.children[0].text.include?("End of") && first_drive == 0
		  				first_drive = index + 1
		  				score = element.children[0].children[0].children[1]
		  				away_result = score.children[0].children[1].text
		  				home_result = score.children[1].children[1].text
		  				break
		  			end
		  		end

		  		if kicked == 1
		  			kicked = "home"
		  		elsif kicked == 0
		  			kicked = "away"
		  		else
		  			kicked = ""
		  		end

		  		home_team_total = home_team_rushing + home_team_passing
		  		away_team_total = away_team_rushing + away_team_passing

				home_ave_car = 0
				if home_car != 0
					home_ave_car = (home_team_rushing.to_f / home_car).round(2)
				end
				away_ave_car = 0
				if away_car != 0
					away_ave_car = (away_team_rushing.to_f / away_car).round(2)
				end

				home_c_att = home_c.to_s + "/" + home_attr.to_s
				away_c_att = away_c.to_s + "/" + away_attr.to_s

				home_ave_att = 0
				if home_attr != 0
					home_ave_att = (home_team_passing.to_f / home_attr).round(2)
				end
				away_ave_att = 0
				if away_attr != 0
					away_ave_att = (away_team_passing.to_f / away_attr).round(2)
				end

				home_total_play = home_car + home_attr
				home_play_yard 	= 0
				if home_total_play != 0
					home_play_yard 	= home_team_total.to_f / home_total_play
				end

				away_total_play = away_car + away_attr
				away_play_yard 	= 0
				if away_total_play != 0
					away_play_yard 	= away_team_total.to_f / away_total_play
				end

			  	unless score = game.scores.find_by(result: "Half")
				  	score = game.scores.create(result: "Half")
				end
				score.update(game_status: game_status, home_team_total: home_team_total, away_team_total: away_team_total, home_team_rushing: home_team_rushing, away_team_rushing: away_team_rushing, home_result: home_result, away_result: away_result, home_car: home_car, home_ave_car: home_ave_car, home_rush_long: home_rush_long, home_c_att: home_c_att, home_ave_att: home_ave_att, home_total_play: home_total_play, home_play_yard: home_play_yard, away_car: away_car, away_ave_car: away_ave_car, away_rush_long: away_rush_long, away_c_att: away_c_att, away_ave_att: away_ave_att, away_total_play: away_total_play, away_play_yard: away_play_yard, home_pass_long: home_pass_long, away_pass_long: away_pass_long)
				
			end

			url = "http://www.espn.com/#{game_link}/game?gameId=#{game_id}"
	  		doc = download_document(url)
			puts url
	  		element = doc.css(".game-date-time").first
	  		game_date = element.children[1]['data-date']

  			game.update(away_team: away_team, home_team: home_team, game_type: game_type, game_date: game_date, home_abbr: home_abbr, away_abbr: away_abbr, kicked: kicked, game_state: game_state, game_status: game_status, first_drive: first_drive, second_drive: second_drive)
  			
	  	end
	end

	task :export => :environment do
		games = Game.where("game_state = 5")
		games.each do |game|
			unless export = Export.find_by(game_id: game.game_id)
				export = Export.create(game_id: game.game_id)
			end
			export.update(home_team: game.home_team,
				away_team: game.away_team,
				game_id: game.game_id,
				game_date: game.game_date,
				home_abbr: game.home_abbr,
				away_abbr: game.away_abbr,
				game_type: game.game_type)
			if score = game.scores.find_by(result: "Half")
				away_c = 0
				away_att = 0
				if away_c_att = score.away_c_att
					if away_index = away_c_att.index('/')
						away_c = away_c_att[0..away_index-1]
						away_att = away_c_att[away_index+1..-1]
					end
				end
				home_c = 0
				home_att = 0
				if home_c_att = score.home_c_att
					if home_index = home_c_att.index('/')
						home_c = home_c_att[0..home_index-1]
						home_att = home_c_att[home_index+1..-1]
					end
				end
				export.update(away_team_total: score.away_team_total,
					away_team_rushing: score.away_team_rushing,
					away_car: score.away_car,
					away_ave_car: score.away_ave_car,
					away_pass_long: score.away_pass_long,
					away_rush_long: score.away_rush_long,
					away_c: away_c,
					away_att: away_att,
					away_ave_att: score.away_ave_att,
					away_total_play: score.away_total_play,
					away_play_yard: score.away_play_yard,

					home_team_total: score.home_team_total,
					home_team_rushing: score.home_team_rushing,
					home_car: score.home_car,
					home_ave_car: score.home_ave_car,
					home_pass_long: score.home_pass_long,
					home_rush_long: score.home_rush_long,
					home_c: home_c,
					home_att: home_att,
					home_ave_att: score.home_ave_att,
					home_total_play: score.home_total_play,
					home_play_yard: score.home_play_yard)
			end
		end
	end

	task :exportScore => :environment do
		include Api
		exports = Export.where("zipcode is null")
		exports.each do |export|
			url = "http://www.espn.com/nfl/game?gameId=#{export.game_id}"
			if export.game_type == 'CFB'
				url = "http://www.espn.com/college-football/game?gameId=#{export.game_id}"
			end
			puts url
			doc = download_document(url)
			element = doc.css('#linescore td')
			away_first_point = element[1].text.to_i
			away_second_point = element[2].text.to_i
			away_third_point = element[3].text.to_i
			away_forth_point = element[4].text.to_i
			away_total_point = element[5].text.to_i

	  		home_first_point = element[7].text.to_i
	  		home_second_point = element[8].text.to_i
	  		home_third_point = element[9].text.to_i
	  		home_forth_point = element[10].text.to_i
	  		home_total_point = element[11].text.to_i

	  		element = doc.css('.game-field .caption-wrapper').first
	  		unless element
	  			element = doc.css('.location-details').first
	  			element = element.children[1]
	  		end
	  		stadium = ''
	  		if element
	  			stadium = element.text.squish
	  		end

	  		element = doc.css('.icon-location-solid-before').first
	  		zipcode = ''
	  		if element
	  			zipcode = element.children[1].text.squish.to_i
	  		end

			export.update(
				away_first_point: away_first_point,
				away_second_point: away_second_point,
				away_first_half_point: away_first_point + away_second_point,
				away_third_point: away_third_point,
				away_forth_point: away_forth_point,
				away_second_half_point: away_third_point + away_forth_point,
				away_total_point: away_total_point,

				home_first_point: home_first_point,
				home_second_point: home_second_point,
				home_first_half_point: home_first_point + home_second_point,
				home_third_point: home_third_point,
				home_forth_point: home_forth_point,
				home_second_half_point: home_third_point + home_forth_point,
				home_total_point: home_total_point,

				stadium: stadium,
				zipcode: zipcode)
		end
	end
	task :creatingStadium => :environment do
		include Api
		exports = Export.all
		exports.each do |export|
			unless stadium = Stadium.find_by(stadium: export.stadium)
				stadium = Stadium.create(stadium: export.stadium, zipcode: export.zipcode)
			end
		end
	end
	task :getLocalTime => :environment do
		include Api
		exports = Export.all
		exports.each do |export|
			date = DateTime.parse(export.game_date).utc
			stadium = Stadium.find_by(stadium: export.stadium)
			date = date + stadium.timezone.to_i.hours
			export.update(time: date.strftime("%I:%M%p"), year: date.strftime("%Y"), date: date.strftime("%^b %e"), week: date.strftime("%^A"))
		end
	end

	task :getLines => :environment do
		Rake::Task["setup:getFirstLines"].invoke
		Rake::Task["setup:getFirstLines"].reenable

		link = "https://www.sportsbookreview.com/betting-odds/nfl-football/2nd-half/?date="
		Rake::Task["setup:getSecondLines"].invoke("second", link)
		Rake::Task["setup:getSecondLines"].reenable

		link = "https://www.sportsbookreview.com/betting-odds/nfl-football/?date="
		Rake::Task["setup:getSecondLines"].invoke("full", link)
		Rake::Task["setup:getSecondLines"].reenable

		link = "https://www.sportsbookreview.com/betting-odds/nfl-football/totals/1st-half/?date="
		Rake::Task["setup:getSecondLines"].invoke("firstTotal", link)
		Rake::Task["setup:getSecondLines"].reenable

		link = "https://www.sportsbookreview.com/betting-odds/nfl-football/totals/2nd-half/?date="
		Rake::Task["setup:getSecondLines"].invoke("secondTotal", link)
		Rake::Task["setup:getSecondLines"].reenable

		link = "https://www.sportsbookreview.com/betting-odds/nfl-football/totals/?date="
		Rake::Task["setup:getSecondLines"].invoke("fullTotal", link)
		Rake::Task["setup:getSecondLines"].reenable
	end

	task :getFirstLines => [:environment] do
		include Api
		games = Export.all
		puts "----------Get First Lines----------"

		index_date = Date.yesterday
		while index_date <= Date.tomorrow  do
			game_day = index_date.strftime("%Y%m%d")
			puts game_day
			url = "https://www.sportsbookreview.com/betting-odds/nfl-football/1st-half/?date=#{game_day}"
			doc = download_document(url)
			elements = doc.css(".event-holder")
			elements.each do |element|
				if element.children[0].children[1].children.size > 2 && element.children[0].children[1].children[2].children[1].children.size == 1
					next
				end
				if element.children[0].children[5].children.size < 5
					next
				end

				if element.children[0].children[3].children.size < 3
					next
				end

				score_element = element.children[0].children[11]

				if score_element.children[1].text == ""
					score_element = element.children[0].children[9]
				end

				if score_element.children[1].text == ""
					score_element = element.children[0].children[13]
				end

				if score_element.children[1].text == ""
					score_element = element.children[0].children[12]
				end

				if score_element.children[1].text == ""
					score_element = element.children[0].children[10]
				end

				if score_element.children[1].text == ""
					score_element = element.children[0].children[17]
				end

				if score_element.children[1].text == ""
					score_element = element.children[0].children[18]
				end

				if score_element.children[1].text == ""
					score_element = element.children[0].children[14]
				end

				if score_element.children[1].text == ""
					score_element = element.children[0].children[15]
				end

				if score_element.children[1].text == ""
					score_element = element.children[0].children[16]
				end

				home_name 		= element.children[0].children[5].children[1].text
				away_name 		= element.children[0].children[5].children[0].text
				home_number 	= element.children[0].children[3].children[2].text
				away_number 	= element.children[0].children[3].children[1].text
				closer 			= score_element.children[1].text
				
				game_time = element.children[0].children[4].text
				ind = game_time.index(":")
				hour = ind ? game_time[0..ind-1].to_i : 0
				min = ind ? game_time[ind+1..ind+3].to_i : 0
				ap = game_time[-1]
				if ap == "p" && hour != 12
					hour = hour + 12
				end
				if ap == "a" && hour == 12
					hour = 24
				end

				if @nba_nicknames[home_name]
			      home_name = @nba_nicknames[home_name]
			    end
			    if @nba_nicknames[away_name]
			      away_name = @nba_nicknames[away_name]
			    end
				date = Time.new(game_day[0..3], game_day[4..5], game_day[6..7]).change(hour: 0, min: min).in_time_zone('Eastern Time (US & Canada)') + 5.hours +  hour.hours

				line_two = closer.index(" ")
				closer_side = line_two ? closer[0..line_two] : ""
				closer_total = line_two ? closer[line_two+2..-1] : ""

				matched = games.select{|field| ((field.home_team.include?(home_name) && field.away_team.include?(away_name)) || (field.home_team.include?(away_name) && field.away_team.include?(home_name))) && (date == field.game_date) }
				if matched.size > 0
					update_game = matched.first
					if closer_side.include?('½')
						if closer_side[0] == '-'
							closer_side = closer_side[0..-1].to_f - 0.5
						elsif
							closer_side = closer_side[0..-1].to_f + 0.5
						end
					else
						closer_side = closer_side.to_f
					end
					update_game.update(first_side: closer_side)
					if update_game.home_team.include?(home_name)
						update_game.update(home_number: home_number, away_number: away_number)
					else
						update_game.update(away_number: home_number, home_number: away_number)
					end
				end
			end
			index_date = index_date + 1.days
		end
	end
		
	task :getSecondLines, [:type, :game_link] => [:environment] do |t, args|
		include Api
		games = Export.all
		game_link = args[:game_link]
		type = args[:type]
		puts "----------Get #{type} Lines----------"

		index_date = Date.yesterday
		while index_date <= Date.tomorrow  do
			game_day = index_date.strftime("%Y%m%d")
			puts game_day
			url = "#{game_link}#{game_day}"
			doc = download_document(url)
			elements = doc.css(".event-holder")
			elements.each do |element|
				if element.children[0].children[1].children.size > 2 && element.children[0].children[1].children[2].children[1].children.size == 1
					next
				end
				if element.children[0].children[5].children.size < 5
					next
				end
				score_element = element.children[0].children[11]

				if score_element.children[1].text == ""
					score_element = element.children[0].children[9]
				end

				if score_element.children[1].text == ""
					score_element = element.children[0].children[13]
				end

				if score_element.children[1].text == ""
					score_element = element.children[0].children[12]
				end

				if score_element.children[1].text == ""
					score_element = element.children[0].children[10]
				end

				if score_element.children[1].text == ""
					score_element = element.children[0].children[17]
				end

				if score_element.children[1].text == ""
					score_element = element.children[0].children[18]
				end

				if score_element.children[1].text == ""
					score_element = element.children[0].children[14]
				end

				if score_element.children[1].text == ""
					score_element = element.children[0].children[15]
				end

				if score_element.children[1].text == ""
					score_element = element.children[0].children[16]
				end

				home_name 		= element.children[0].children[5].children[1].text
				away_name 		= element.children[0].children[5].children[0].text
				closer 			= score_element.children[1].text
				
				game_time = element.children[0].children[4].text
				ind = game_time.index(":")
				hour = ind ? game_time[0..ind-1].to_i : 0
				min = ind ? game_time[ind+1..ind+3].to_i : 0
				ap = game_time[-1]
				if ap == "p" && hour != 12
					hour = hour + 12
				end
				if ap == "a" && hour == 12
					hour = 24
				end

				if @nba_nicknames[home_name]
			      home_name = @nba_nicknames[home_name]
			    end
			    if @nba_nicknames[away_name]
			      away_name = @nba_nicknames[away_name]
			    end
				date = Time.new(game_day[0..3], game_day[4..5], game_day[6..7]).change(hour: 0, min: min).in_time_zone('Eastern Time (US & Canada)') + 5.hours +  hour.hours

				line_two = closer.index(" ")
				closer_side = line_two ? closer[0..line_two] : ""
				closer_total = line_two ? closer[line_two+2..-1] : ""

				matched = games.select{|field| ((field.home_team.include?(home_name) && field.away_team.include?(away_name)) || (field.home_team.include?(away_name) && field.away_team.include?(home_name))) && (date == field.game_date) }
				if matched.size > 0
					update_game = matched.first
					if closer_side.include?('½')
						if closer_side[0] == '-'
							closer_side = closer_side[0..-1].to_f - 0.5
						elsif
							closer_side = closer_side[0..-1].to_f + 0.5
						end
					else
						closer_side = closer_side.to_f
					end
					if type == "second"
						update_game.update(second_side: closer_side)
					elsif type == "full"
						update_game.update(full_side: closer_side)
					elsif type == "firstTotal"
						update_game.update(first_total: closer_side)
					elsif type == "secondTotal"
						update_game.update(second_total: closer_side)
					elsif type == "fullTotal"
						update_game.update(full_total: closer_side)
					end
				end
			end
			index_date = index_date + 1.days
		end
	end
	@nicknames = {
		"Hawaii" => "Hawai'i",
		"San Jose State" => "San José State",
		"Brigham Young" => "BYU",
		"Massachusetts" => "UMass",
		"Florida International" => "Florida Intl",
		"Louisiana-Monroe" => "Louisiana Monroe",
		"Central Connecticut State" => "Central Connecticu",
		"Virginia Military Institute" => "VMI",
		"North Carolina State" => "NC State",
		"Louisiana-Lafayette" => "Louisiana",
		"Grambling State" => "Grambling",
		"Tennessee-Martin" => "UT Martin",
		"Southern Methodist" => "SMU",
		"Nicholls State" => "Nicholls",
		"Southern University" => "Southern",
		"Southern Miss" => "Southern Mississippi",
		"UTSA" => "UT San Antonio",
		"N.Y. Jets" => "New York",
		"L.A. Rams" => "Los Angeles",
		"N.Y. Giants" => "New York",
		"L.A. Chargers" => "Los Angeles",
		"Los Angeles" => "St. Louis",
		"SC State" => "South Carolina State",
		"Stephen F. Austin" => "Stephen F Austin",
		"NC Central" => "North Carolina Central",
	}
end