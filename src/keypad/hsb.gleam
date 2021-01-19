import gleam/int
import gleam/float
import utils/int_extra
import utils/float_extra

pub opaque type Hsb {
  Hsb(value: Int)
}

pub fn zero() -> Hsb {
  Hsb(0)
}

pub fn one() -> Hsb {
  Hsb(1)
}

pub fn from_int(value: Int) -> Hsb {
  Hsb(value)
}

pub fn to_int(hsb: Hsb) -> Int {
  hsb.value
}

pub fn increment(hsb: Hsb, percentage: Float) -> Hsb {
  let clamped_percentage = float_extra.clamp(percentage, -1.0, 1.0)
  let diff = float.round(clamped_percentage *. 65_535.0)
  hsb.value + diff
  |> int_extra.clamp(0, 65_535)
  |> Hsb
}
