class WelcomeController < ApplicationController

  before_action :confirm_logged_in

  def index
    unless params[:teamPicker]
      params[:teamPicker] = false
    end
    @teamPicker = params[:teamPicker]
    unless params[:id]
      params[:id] = Time.now.strftime("%Y-%m-%d") + " - " + Time.now.strftime("%Y-%m-%d")
    end
    @game_index = params[:id]
    if params[:teamPicker] != false
			@games = Game.where("home_team = ?", @game_index).or(Game.where("away_team = ?", @game_index))
									 .order("game_state")
									 .order("game_status")
									 .order("game_date")
    else
			@game_start_index = @game_index[0..9]
			@game_end_index = @game_index[13..23]
      @games = Game.where("game_date between ? and ?", Date.strptime(@game_start_index).beginning_of_day, Date.strptime(@game_end_index).end_of_day)
                   .order("game_state")
                   .order("game_status")
                   .order("game_date")
    end
    @teams = Game.distinct.pluck(:home_team)
		@away_teams = Game.distinct.pluck(:away_team)
		@teams.concat(@away_teams).uniq
  end
end
