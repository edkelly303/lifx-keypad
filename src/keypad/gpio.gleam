import gleam/atom.{Atom}
import gleam/result
import gleam/dynamic.{Dynamic}
import utils/dynamic_extra

pub external type Pin

pub type Error {
  FailedToOpenGPIOPin(Int)
  FailedToSetPullMode
  FailedToSetPinDirection
}

pub type PinDirection {
  Input
  Output
}

pub type PullMode {
  NotSet
  Pullup
  Pulldown
  None
}

pub type Value {
  Zero
  One
}

fn value_to_int(value: Value) -> Int {
  case value {
    Zero -> 0
    One -> 1
  }
}

/// Open a GPIO pin for use.
/// `pin` should be a valid GPIO pin number on the system
/// `pin_direction` should be `Input` or `Output`. 
/// If opening as an output, use `open_with_initial_value` to avoid glitches.
pub fn open(pin_number: Int, pin_direction: PinDirection) -> Result(Pin, Error) {
  ext_gpio_open(pin_number, pin_direction)
  |> result.map_error(fn(_) { FailedToOpenGPIOPin(pin_number) })
}

external fn ext_gpio_open(
  pin_number: Int,
  pin_direction: PinDirection,
) -> Result(Pin, Atom) =
  "circuits_gpio" "open"

/// Enable or disable the internal pull-up or pull-down resistor for the GPIO pin
pub fn set_pull_mode(pin: Pin, pull_mode: PullMode) -> Result(Pin, Error) {
  assert Ok(decoded_result) =
    pin
    |> ext_set_pull_mode(pull_mode)
    |> dynamic_extra.ok_atom_or_error_reason_tuple()
  decoded_result
  |> result.map(fn(_) { pin })
  |> result.map_error(fn(_) { FailedToSetPullMode })
}

external fn ext_set_pull_mode(Pin, PullMode) -> Dynamic =
  "circuits_gpio" "set_pull_mode"

/// Change the direction of the GPIO pin to use it as Input or Output
pub fn set_pin_direction(
  pin: Pin,
  pin_direction: PinDirection,
) -> Result(Pin, Error) {
  assert Ok(decoded_result) =
    ext_set_pin_direction(pin, pin_direction)
    |> dynamic_extra.ok_atom_or_error_reason_tuple()
  decoded_result
  |> result.map(fn(_) { pin })
  |> result.map_error(fn(_) { FailedToSetPinDirection })
}

external fn ext_set_pin_direction(Pin, PinDirection) -> Dynamic =
  "circuits_gpio" "set_direction"

/// Close the GPIO pin
pub fn close(pin: Pin) -> Nil {
  let _ = ext_close(pin)
  Nil
}

external fn ext_close(pin: Pin) -> Atom =
  "circuits_gpio" "close"

/// Read the value of the GPIO pin
pub fn read(pin: Pin) -> Value {
  assert Ok(value) = case ext_read(pin) {
    0 -> Ok(Zero)
    1 -> Ok(One)
    _ ->
      Error(
        "It should be impossible to read any values other than 0 or 1 from a GPIO pin",
      )
  }
  value
}

external fn ext_read(pin: Pin) -> Int =
  "circuits_gpio" "read"

/// Write a value to the GPIO pin
pub fn write(pin: Pin, value: Value) -> Nil {
  ext_write(pin, value_to_int(value))
  Nil
}

external fn ext_write(pin: Pin, value: Int) -> Atom =
  "circuits_gpio" "read"
