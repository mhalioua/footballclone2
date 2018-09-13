module WelcomeHelper
  def lineToString(home, away, home_abbr, away_abbr, is)
    pinnacle = ""
    if home
      home_pinnacle = home
      away_pinnacle = away
      home_pinnacle, away_pinnacle = away, home if home_pinnacle[0] != "-"
      index = home_pinnacle.index(" ")
      pinnacle = index ? home_pinnacle[0..index-1] : ""
      index = away_pinnacle.index(" ")
      if index
        if pinnacle != ""
          pinnacle = pinnacle + " and "
        end
        pinnacle = pinnacle + away_pinnacle[0..index-1]
      end
    end
    if pinnacle != ""
      if home[0] == "-"
        pinnacle = home_abbr + is + pinnacle
      else
        pinnacle = away_abbr + is + pinnacle
      end
    end
    return pinnacle
  end
end
