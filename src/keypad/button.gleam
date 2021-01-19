import gleam/int
import gleam/result
import keypad/gpio
import keypad/group.{Group}
import keypad/power.{Off, On, Power}

pub type Button {
  ToggleGroup(Group)
  Power(Power)
  Temperature(UpDown)
  Brightness(UpDown)
  Select(AllNone)
}

pub type ButtonState {
  ButtonState(state: UpDown, pin: gpio.Pin)
}

pub type UpDown {
  Up
  Down
}

pub type AllNone {
  All
  None
}

pub fn all() -> List(Button) {
  [
    Power(Off),
    Brightness(Down),
    Temperature(Down),
    Select(None),
    Power(On),
    Brightness(Up),
    Temperature(Up),
    Select(All),
    ToggleGroup(group.Bedroom),
    ToggleGroup(group.DiningRoom),
    ToggleGroup(group.LivingRoom),
    ToggleGroup(group.Study),
  ]
}

pub fn init(button: Button) -> tuple(Button, ButtonState) {
  assert Ok(pin) =
    button
    |> to_pin_number
    |> gpio.open(gpio.Input)
    |> result.then(fn(pin) { gpio.set_pull_mode(pin, gpio.Pullup) })
  tuple(button, ButtonState(state: Up, pin: pin))
}

pub fn read_state(button_state: ButtonState) -> ButtonState {
  let new_state =
    button_state.pin
    |> gpio.read()
    |> state_from_value()
  ButtonState(..button_state, state: new_state)
}

fn state_from_value(value: gpio.Value) -> UpDown {
  case value {
    gpio.Zero -> Down
    gpio.One -> Up
  }
}

pub fn to_pin_number(button: Button) -> Int {
  case button {
    ToggleGroup(group.Bedroom) -> 26
    ToggleGroup(group.DiningRoom) -> 13
    ToggleGroup(group.LivingRoom) -> 5
    ToggleGroup(group.Study) -> 23
    Power(On) -> 16
    Power(Off) -> 20
    Brightness(Up) -> 12
    Brightness(Down) -> 6
    Temperature(Up) -> 22
    Temperature(Down) -> 24
    Select(All) -> 27
    Select(None) -> 17
  }
}
