import gleam/list
import gleam/result
import gleam/pair
import gleam/int
import gleam/map.{Map}
import keypad/gpio
import keypad/button.{Button, ButtonState}

pub type Keypad {
  Keypad(buttons: Map(Button, ButtonState))
}

pub fn init() -> Keypad {
  Keypad(
    buttons: button.all()
    |> list.map(button.init)
    |> map.from_list,
  )
}

pub fn read(keypad: Keypad) -> Keypad {
  keypad.buttons
  |> map.map_values(fn(_button, button_state) {
    button.read_state(button_state)
  })
  |> Keypad
}

pub type Diff {
  Diff(ups: List(Button), downs: List(Button))
}

pub fn diff(old old: Keypad, new new: Keypad) -> Diff {
  button.all()
  |> list.fold(
    Diff(ups: [], downs: []),
    fn(button_, output: Diff) {
      case get_button_state(old, button_), get_button_state(new, button_) {
        Ok(bs1), Ok(bs2) ->
          Diff(ups: case bs1.state == button.Down && bs2.state == button.Up {
              True -> [button_, ..output.ups]
              False -> output.ups
            }, downs: case bs1.state == button.Up && bs2.state == button.Down {
              True -> [button_, ..output.downs]
              False -> output.downs
            })
        _, _ -> output
      }
    },
  )
}

fn get_button_state(keypad: Keypad, button: Button) -> Result(ButtonState, Nil) {
  keypad.buttons
  |> map.get(button)
}
