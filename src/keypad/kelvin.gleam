import gleam/int
import gleam/float
import utils/int_extra
import utils/float_extra

pub opaque type Kelvin {
  Kelvin(value: Int)
}

const coolest: Int = 6_000

const warmest: Int = 1_500

pub fn zero() -> Kelvin {
  Kelvin(warmest)
}

pub fn one() -> Kelvin {
  Kelvin(coolest)
}

pub fn from_int(value: Int) -> Kelvin {
  value
  |> int_extra.clamp(warmest, coolest)
  |> Kelvin
}

pub fn to_int(kelvin: Kelvin) -> Int {
  kelvin.value
}

pub fn increment(kelvin: Kelvin, percentage: Float) -> Kelvin {
  let clamped_percentage = float_extra.clamp(percentage, -1.0, 1.0)
  let diff = float.round(clamped_percentage *. int.to_float(coolest - warmest))
  kelvin.value + diff
  |> int_extra.clamp(warmest, coolest)
  |> Kelvin
}
