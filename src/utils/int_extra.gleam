import gleam/int

pub fn clamp(flt: Int, max bound1: Int, min bound2: Int) {
  let high = int.max(bound1, bound2)
  let low = int.min(bound1, bound2)
  flt
  |> at_least(low)
  |> at_most(high)
}

pub fn at_least(flt: Int, at_least: Int) -> Int {
  int.max(flt, at_least)
}

pub fn at_most(flt: Int, at_most: Int) -> Int {
  int.min(flt, at_most)
}
