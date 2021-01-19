import gleam/float

pub fn clamp(flt: Float, max bound1: Float, min bound2: Float) {
  let high = float.max(bound1, bound2)
  let low = float.min(bound1, bound2)
  flt
  |> at_least(low)
  |> at_most(high)
}

pub fn at_least(flt: Float, at_least: Float) -> Float {
  float.max(flt, at_least)
}

pub fn at_most(flt: Float, at_most: Float) -> Float {
  float.min(flt, at_most)
}
