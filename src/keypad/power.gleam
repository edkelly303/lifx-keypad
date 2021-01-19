pub type Power {
  Off
  On
}

pub fn to_int(power: Power) -> Int {
  case power {
    On -> 65_535
    Off -> 0
  }
}

pub fn from_int(power: Int) -> Power {
  case power == 65_535 {
    True -> On
    False -> Off
  }
}
