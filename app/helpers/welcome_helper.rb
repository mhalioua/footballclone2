module WelcomeHelper
  def stringTofloat(value)
    index = value.index(" ")
    pinnacle = index ? value[0..index-1] : ""
    if pinnacle.include?('½')
      if pinnacle[0] == '-'
        pinnacle = pinnacle[0..-1].to_f - 0.5
      else
        pinnacle = pinnacle[0..-1].to_f + 0.5
      end
    else
      pinnacle = pinnacle.to_f
    end
    return pinnacle
  end

  def lineToString(home, away)
    return if home == nil || away == nil || home == '' || away == ''
    if home[0] == "-"
      spread = stringTofloat(home)
      total = stringTofloat(away)
    else
      spread = stringTofloat(away[1..-1])
      total = stringTofloat(home)
    end
    return spread.to_s + ' and ' + total.to_s
  end
end
