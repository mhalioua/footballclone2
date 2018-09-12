module WelcomeHelper
  def lineToString(home, away, home_abbr, away_abbr)
    pinnacle = ""
    if home
      home, away = away, home if home[0] != "-"

      index = home.index(" ")
      pinnacle = index ? home[0..index - 1] : ""

      index = away.index(" ")
      if index
        pinnacle = pinnacle + " and " if pinnacle != ""
        pinnacle = pinnacle + away[0..index - 1]
      end

    end
    if pinnacle != ""
      if away == "-"
        pinnacle = home_abbr + " was " + pinnacle
      else
        pinnacle = away_abbr + " was " + pinnacle
      end
    end
    return pinnacle
  end
end
