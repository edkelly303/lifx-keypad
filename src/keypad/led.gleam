import gleam/int
import gleam/list
import gleam/map
import gleam/pair
import gleam/set.{Set}
import gleam/order.{Order}
import gleam/bit_builder.{BitBuilder}
import gleam/bit_string.{BitString}
import keypad/button.{Button, ButtonState}
import keypad/keypad.{Keypad}
import keypad/spi.{Bus}
import keypad/power
import keypad/group.{Group}

//
// Rendering LEDs
//
type Led {
  Led(colour: Colour, brightness: Brightness)
}

pub fn turn_off(bus: Bus) -> Result(BitString, spi.ErrorType) {
  Led(colour: black(), brightness: zero_brightness())
  |> list.repeat(12)
  |> build_packet()
  |> spi.transfer(bus, _)
}

pub fn refresh(
  keypad: Keypad,
  selected_groups: Set(Group),
  bus: Bus,
) -> Result(BitString, spi.ErrorType) {
  keypad.buttons
  |> map.to_list
  |> list.sort(fn(b1, b2) {
    compare_by_led_index(pair.first(b1), pair.first(b2))
  })
  |> list.map(fn(button_and_state) {
    let tuple(button, button_state) = button_and_state
    let brightness = brightness_from_button_state(button_state)
    let colour = colour_from_button(button, selected_groups)
    Led(colour: colour, brightness: brightness)
  })
  |> build_packet()
  |> spi.transfer(bus, _)
}

fn compare_by_led_index(b1: Button, b2: Button) -> Order {
  int.compare(led_index_from_button(b1), led_index_from_button(b2))
}

fn led_index_from_button(button: Button) -> Int {
  case button {
    button.Power(power.Off) -> 0
    button.Brightness(button.Down) -> 1
    button.Temperature(button.Up) -> 2
    button.Select(button.None) -> 3
    button.Power(power.On) -> 4
    button.Brightness(button.Up) -> 5
    button.Temperature(button.Down) -> 6
    button.Select(button.All) -> 7
    button.ToggleGroup(group.Bedroom) -> 8
    button.ToggleGroup(group.DiningRoom) -> 9
    button.ToggleGroup(group.LivingRoom) -> 10
    button.ToggleGroup(group.Study) -> 11
  }
}

//
// Building packets
//
const start_frame: BitString = <<0:big-int-unit(8)-size(4)>>

const end_frame: BitString = <<
  255:big-int-size(8), 255:big-int-size(8), 255:big-int-size(8), 255:big-int-size(8),
>>

fn build_packet(led_list: List(Led)) -> BitString {
  let leds = build_led_frames(led_list)
  bit_builder.from_bit_string(start_frame)
  |> bit_builder.append_builder(leds)
  |> bit_builder.append(end_frame)
  |> bit_builder.to_bit_string()
}

fn build_led_frames(led_list: List(Led)) -> BitBuilder {
  led_list
  |> list.fold(
    from: bit_builder.from_bit_string(<<>>),
    with: fn(led: Led, builder) {
      led
      |> build_led_frame()
      |> bit_builder.append(builder, _)
    },
  )
}

fn build_led_frame(led: Led) -> BitString {
  <<
    1:big-int-unit(1)-size(1),
    1:big-int-unit(1)-size(1),
    1:big-int-unit(1)-size(1),
    brightness_to_int(led.brightness):big-int-unit(1)-size(5),
    led.colour.blue:big-int-unit(1)-size(8),
    led.colour.green:big-int-unit(1)-size(8),
    led.colour.red:big-int-unit(1)-size(8),
  >>
}

//
// Colours
//
type Colour {
  Colour(red: Int, green: Int, blue: Int)
}

fn colour_from_button(button: Button, selected_groups: Set(Group)) -> Colour {
  case button {
    button.ToggleGroup(g) ->
      case set.contains(selected_groups, g) {
        True -> white()
        False -> black()
      }
    button.Power(power.On) -> green()
    button.Power(power.Off) -> red()
    button.Temperature(button.Up) -> blue()
    button.Temperature(button.Down) -> yellow()
    button.Brightness(button.Up) -> white()
    button.Brightness(button.Down) -> black()
    button.Select(button.All) -> white()
    button.Select(button.None) -> black()
  }
}

fn new(red red: Int, green green: Int, blue blue: Int) -> Colour {
  Colour(
    red: red
    |> int.max(0)
    |> int.min(255),
    green: green
    |> int.max(0)
    |> int.min(255),
    blue: blue
    |> int.max(0)
    |> int.min(255),
  )
}

fn white() -> Colour {
  new(red: 255, green: 255, blue: 255)
}

fn red() -> Colour {
  new(red: 255, green: 0, blue: 0)
}

fn green() -> Colour {
  new(red: 0, green: 255, blue: 0)
}

fn blue() -> Colour {
  new(red: 0, green: 0, blue: 255)
}

fn black() -> Colour {
  new(red: 0, green: 0, blue: 0)
}

fn yellow() -> Colour {
  new(red: 255, green: 255, blue: 0)
}

//
// Brightness
//
pub type Brightness {
  Brightness(Int)
}

fn brightness_from_button_state(button_state: ButtonState) -> Brightness {
  case button_state.state {
    button.Up -> minimum_brightness()
    button.Down -> full_brightness()
  }
}

fn brightness(int_: Int) -> Brightness {
  int_
  |> int.max(0)
  |> int.min(31)
  |> Brightness
}

fn full_brightness() -> Brightness {
  brightness(31)
}

fn minimum_brightness() -> Brightness {
  brightness(1)
}

fn zero_brightness() -> Brightness {
  brightness(0)
}

fn brightness_to_int(brightness: Brightness) -> Int {
  let Brightness(int) = brightness
  int
}
