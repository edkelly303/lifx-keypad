import gleam/dynamic.{Dynamic}
import gleam/result

pub type IPAddress =
  tuple(Int, Int, Int, Int)

pub const broadcast = tuple(192, 168, 1, 255)

pub fn decoder(dyn: Dynamic) -> Result(IPAddress, String) {
  try zero =
    dynamic.element(dyn, 0)
    |> result.then(dynamic.int)
  try one =
    dynamic.element(dyn, 1)
    |> result.then(dynamic.int)
  try two =
    dynamic.element(dyn, 2)
    |> result.then(dynamic.int)
  try three =
    dynamic.element(dyn, 3)
    |> result.then(dynamic.int)
  Ok(tuple(zero, one, two, three))
}
