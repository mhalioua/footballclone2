namespace :nba do
	task :daily => :environment do
		date = Date.new(2014, 10, 16)
		while date < Date.new(2017, 6, 13)  do
			Rake::Task["nba:getDate"].invoke(date.strftime("%Y%m%d"))
			Rake::Task["nba:getDate"].reenable
			date = date + 7.days
		end
	end

	task :getDate, [:game_date] => [:environment] do |t, args|
		include Api
		Time.zone = 'Eastern Time (US & Canada)'
		game_date = args[:game_date]
		url = "http://www.espn.com/nba/schedule/_/date/#{game_date}"
		doc = download_document(url)
		puts url
	  	index = { away_team: 0, home_team: 1, result: 2 }
	  	elements = doc.css("tr")
	  	elements.each do |slice|
	  		if slice.children.size < 5
	  			next
	  		end
	  		away_team = slice.children[index[:away_team]].text
	  		if away_team == "matchup"
	  			next
	  		end
	  		href = slice.children[index[:result]].child['href']
	  		game_id = href[-9..-1]
	  		unless game = Nba.find_by(game_id: game_id)
              	game = Nba.create(game_id: game_id)
            end
           
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

        	if @nba_nicknames[home_team]
		      home_team = @nba_nicknames[home_team]
		    end
		    if @nba_nicknames[away_team]
		      away_team = @nba_nicknames[away_team]
		    end

	  		url = "http://www.espn.com/nba/game?gameId=#{game_id}"
	  		doc = download_document(url)
			puts url
	  		element = doc.css(".game-date-time").first
	  		game_date = element.children[1]['data-date']
	  		date = DateTime.parse(game_date).in_time_zone
	  		game.update(away_team: away_team, home_team: home_team, home_abbr: home_abbr, away_abbr: away_abbr, game_date: date, year: date.strftime("%Y"), date: date.strftime("%b %e"))
	  	end
	end

	task :getScore => [:environment] do
		include Api

		games = Nba.where("away_first_quarter IS null")
		games.each do |game|
			game_id = game.game_id

			url = "http://www.espn.com/nba/playbyplay?gameId=#{game_id}"
	  		doc = download_document(url)
			puts url
			elements = doc.css("#linescore tbody tr")
			if elements.size > 1
				if elements[0].children.size > 5
					away_first_quarter 	= elements[0].children[1].text.to_i
					away_second_quarter = elements[0].children[2].text.to_i
					away_third_quarter 	= elements[0].children[3].text.to_i
					away_forth_quarter 	= elements[0].children[4].text.to_i
					away_ot_quarter 	= 0

					home_first_quarter 	= elements[1].children[1].text.to_i
					home_second_quarter = elements[1].children[2].text.to_i
					home_third_quarter 	= elements[1].children[3].text.to_i
					home_forth_quarter 	= elements[1].children[4].text.to_i
					home_ot_quarter 	= 0

					if elements[0].children.size > 6
						away_ot_quarter = elements[0].children[5].text.to_i
		  				home_ot_quarter = elements[1].children[5].text.to_i
					end
				end
			else
				away_first_quarter 	= 0
				away_second_quarter = 0
				away_third_quarter 	= 0
				away_forth_quarter 	= 0
				away_ot_quarter 	= 0

				home_first_quarter 	= 0
				home_second_quarter = 0
				home_third_quarter 	= 0
				home_forth_quarter 	= 0
				home_ot_quarter 	= 0
			end
			away_score = away_first_quarter + away_second_quarter + away_third_quarter + away_forth_quarter + away_ot_quarter
			home_score = home_first_quarter + home_second_quarter + home_third_quarter + home_forth_quarter + home_ot_quarter

			game.update(away_first_quarter: away_first_quarter, home_first_quarter: home_first_quarter, away_second_quarter: away_second_quarter, home_second_quarter: home_second_quarter, away_third_quarter: away_third_quarter, home_third_quarter: home_third_quarter, away_forth_quarter: away_forth_quarter, home_forth_quarter: home_forth_quarter, away_ot_quarter: away_ot_quarter, home_ot_quarter: home_ot_quarter, away_score: away_score, home_score: home_score, total_score: home_score + away_score, first_point: home_first_quarter + home_second_quarter + away_first_quarter + away_second_quarter, second_point: home_forth_quarter + away_forth_quarter + away_third_quarter + home_third_quarter, total_point: away_first_quarter + away_second_quarter + away_third_quarter + away_forth_quarter + home_first_quarter + home_second_quarter + home_third_quarter + home_forth_quarter)
		end
	end

	task :getLinkGame => [:environment] do
		include Api

		Time.zone = 'Eastern Time (US & Canada)'

		games = Nba.all
		games.each do |game|
			home_team = game.home_team
			away_team = game.away_team
			game_date = game.game_date
			puts DateTime.parse(game_date).in_time_zone.to_date

			away_last_game = ""
			away_team_prev = Nba.where("home_team = ? AND game_date < ?", away_team, game_date).or(Nba.where("away_team = ? AND game_date < ?", away_team, game_date)).order(:game_date).last
			if away_team_prev
				away_last_game = (DateTime.parse(game_date).in_time_zone.to_date - DateTime.parse(away_team_prev.game_date).in_time_zone.to_date ).to_i - 1
			end

			away_next_game = ""
			away_team_next = Nba.where("home_team = ? AND game_date > ?", away_team, game_date).or(Nba.where("away_team = ? AND game_date > ?", away_team, game_date)).order(:game_date).first
			if away_team_next
				away_next_game = (DateTime.parse(away_team_next.game_date).in_time_zone.to_date  - DateTime.parse(game_date).in_time_zone.to_date ).to_i - 1
			end

			home_last_game = ""
			home_last_fly = ""
			home_team_prev = Nba.where("home_team = ? AND game_date < ?", home_team, game_date).or(Nba.where("away_team = ? AND game_date < ?", home_team, game_date)).order(:game_date).last
			if home_team_prev
				home_last_game = (DateTime.parse(game_date).in_time_zone.to_date - DateTime.parse(home_team_prev.game_date).in_time_zone.to_date ).to_i - 1
				if home_team_prev.home_team == home_team
					home_last_fly = "NO"
				else
					home_last_fly = "YES"
				end
			end

			home_next_game = ""
			home_next_fly = ""
			home_team_next = Nba.where("home_team = ? AND game_date > ?", home_team, game_date).or(Nba.where("away_team = ? AND game_date > ?", home_team, game_date)).order(:game_date).first
			if home_team_next
				home_next_game = (DateTime.parse(home_team_next.game_date).in_time_zone.to_date  - DateTime.parse(game_date).in_time_zone.to_date ).to_i - 1
				if home_team_next.home_team == home_team
					home_next_fly = "NO"
				else
					home_next_fly = "YES"
				end
			end
			game.update(away_last_game: away_last_game, away_next_game: away_next_game, home_last_game: home_last_game, home_next_game: home_next_game, home_next_fly: home_next_fly, home_last_fly: home_last_fly)
		end
	end

	task :getFirstLines => [:environment] do
		include Api
		games = Nba.all

		date = Date.new(2012, 3, 21)
		while date < Date.new(2017, 6, 13)  do
			game_day = date.strftime("%Y%m%d")
			puts game_day
			url = "https://classic.sportsbookreview.com/betting-odds/nba-basketball/merged/1st-half/?date=#{game_day}"
			doc = download_document(url)
			elements = doc.css(".event-holder")
			elements.each do |element|
				if element.children[0].children[1].children.size > 2 && element.children[0].children[1].children[2].children[1].children.size == 1
					next
				end
				if element.children[0].children[5].children.size < 5
					next
				end

				score_element = element.children[0].children[9]

				if score_element.children[1].text == ""
					score_element = element.children[0].children[13]
				end

				if score_element.children[1].text == ""
					score_element = element.children[0].children[11]
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
				home_pinnacle 	= score_element.children[1].text
				away_pinnacle 	= score_element.children[0].text
				
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

				line_one = home_pinnacle.index(" ")
				line_one = line_one ? home_pinnacle[0..line_one] : ""
				line_two = away_pinnacle.index(" ")
				line_two = line_two ? away_pinnacle[0..line_two] : ""
				if line_one == ""
					first_line = line_two
					first_side = ""
				elsif line_one[0] == "-" || line_one[0] == "P"
					first_line = line_two
					first_side = line_one[1..-1]
					if line_one[0] == "P"
						first_side = line_one
					end
				elsif line_two == ""
					first_line = line_one
					first_side = ""
				else
					first_line = line_one
					first_side = line_two[1..-1]
					if line_two[0] == "P"
						first_side = line_two
					end
				end

				matched = games.select{|field| ((field.home_team.include?(home_name) && field.away_team.include?(away_name)) || (field.home_team.include?(away_name) && field.away_team.include?(home_name))) && (date == field.game_date) }
				if matched.size > 0
					update_game = matched.first
					if first_line.include?('½')
						first_line = first_line[0..-1].to_f + 0.5
					else
						first_line = first_line.to_f
					end
					if first_side.include?('½')
						first_side = first_side[0..-1].to_f + 0.5
					else
						first_side = first_side.to_f
					end
					update_game.update(first_line: first_line, first_side: first_side)
				end
			end
			date = date + 1.days
		end
	end

	task :getSecondLines => [:environment] do
		include Api
		games = Nba.all

		date = Date.new(2012, 10, 10)
		while date < Date.new(2017, 6, 13)  do
			game_day = date.strftime("%Y%m%d")
			puts game_day
			url = "https://classic.sportsbookreview.com/betting-odds/nba-basketball/merged/2nd-half/?date=#{game_day}"
			doc = download_document(url)
			elements = doc.css(".event-holder")
			elements.each do |element|
				if element.children[0].children[1].children.size > 2 && element.children[0].children[1].children[2].children[1].children.size == 1
					next
				end
				if element.children[0].children[5].children.size < 5
					next
				end
				score_element = element.children[0].children[9]

				if score_element.children[1].text == ""
					score_element = element.children[0].children[13]
				end

				if score_element.children[1].text == ""
					score_element = element.children[0].children[11]
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
				home_pinnacle 	= score_element.children[1].text
				away_pinnacle 	= score_element.children[0].text
				
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

				line_one = home_pinnacle.index(" ")
				line_one = line_one ? home_pinnacle[0..line_one] : ""
				line_two = away_pinnacle.index(" ")
				line_two = line_two ? away_pinnacle[0..line_two] : ""
				if line_one == ""
					first_line = line_two
					first_side = ""
				elsif line_one[0] == "-" || line_one[0] == "P"
					first_line = line_two
					first_side = line_one[1..-1]
					if line_one[0] == "P"
						first_side = line_one
					end
				elsif line_two == ""
					first_line = line_one
					first_side = ""
				else
					first_line = line_one
					first_side = line_two[1..-1]
					if line_two[0] == "P"
						first_side = line_two
					end
				end

				matched = games.select{|field| ((field.home_team.include?(home_name) && field.away_team.include?(away_name)) || (field.home_team.include?(away_name) && field.away_team.include?(home_name))) && (date == field.game_date) }
				if matched.size > 0
					update_game = matched.first
					if first_line.include?('½')
						first_line = first_line[0..-1].to_f + 0.5
					else
						first_line = first_line.to_f
					end
					if first_side.include?('½')
						first_side = first_side[0..-1].to_f + 0.5
					else
						first_side = first_side.to_f
					end
					update_game.update(second_line: first_line, second_side: first_side)
				end
			end
			date = date + 1.days
		end
	end

	task :getFullLines => [:environment] do
		include Api
		games = Nba.all

		date = Date.new(2006, 10, 1)
		while date < Date.new(2017, 6, 13)  do
			game_day = date.strftime("%Y%m%d")
			puts game_day
			url = "https://classic.sportsbookreview.com/betting-odds/nba-basketball/merged/?date=#{game_day}"
			doc = download_document(url)
			elements = doc.css(".event-holder")
			elements.each do |element|
				if element.children[0].children[1].children.size > 2 && element.children[0].children[1].children[2].children[1].children.size == 1
					next
				end
				if element.children[0].children[5].children.size < 5
					next
				end
				score_element = element.children[0].children[9]

				if score_element.children[1].text == ""
					score_element = element.children[0].children[13]
				end

				if score_element.children[1].text == ""
					score_element = element.children[0].children[11]
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
				home_pinnacle 	= score_element.children[1].text
				away_pinnacle 	= score_element.children[0].text
				
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

				line_one = home_pinnacle.index(" ")
				line_one = line_one ? home_pinnacle[0..line_one] : ""
				line_two = away_pinnacle.index(" ")
				line_two = line_two ? away_pinnacle[0..line_two] : ""
				if line_one == ""
					first_line = line_two
					first_side = ""
				elsif line_one[0] == "-" || line_one[0] == "P"
					first_line = line_two
					first_side = line_one[1..-1]
					if line_one[0] == "P"
						first_side = line_one
					end
				elsif line_two == ""
					first_line = line_one
					first_side = ""
				else
					first_line = line_one
					first_side = line_two[1..-1]
					if line_two[0] == "P"
						first_side = line_two
					end
				end

				matched = games.select{|field| ((field.home_team.include?(home_name) && field.away_team.include?(away_name)) || (field.home_team.include?(away_name) && field.away_team.include?(home_name))) && (date == field.game_date) }
				if matched.size > 0
					update_game = matched.first
					if first_line.include?('½')
						first_line = first_line[0..-1].to_f + 0.5
					else
						first_line = first_line.to_f
					end
					if first_side.include?('½')
						first_side = first_side[0..-1].to_f + 0.5
					else
						first_side = first_side.to_f
					end
					update_game.update(full_line: first_line, full_side: first_side)
				end
			end
			date = date + 1.days
		end
	end

	@nba_nicknames = {
		"L.A. Lakers" => "LAL",
		"Los Angeles" => "LAL",
		"L.A. Clippers" => "LAC",
		"LA" => "LAC"
	}
end