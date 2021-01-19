import gleam/float
import gleam/map.{Map}
import gleam/list.{List}
import gleam/set.{Set}
import gleam/option
import gleam/otp/process.{Sender}
import gleam/otp/actor.{Continue, InitResult, Next, Ready}
import gleam/pair
import gleam/atom.{Atom}
import keypad/udp.{Socket}
import keypad/mac_address.{MacAddress}
import keypad/port
import keypad/power.{Power}
import keypad/ip_address.{IPAddress}
import keypad/device.{Device}
import keypad/bulb.{Bulb}
import keypad/incoming_msg
import keypad/outgoing_msg
import keypad/group.{Group}
import keypad/led
import keypad/button.{Button}
import keypad/spi.{Bus}
import keypad/keypad.{Keypad}
import keypad/kelvin
import keypad/hsb
import utils/int_extra
import utils/float_extra

type Model {
  Model(
    time: Int,
    last_key_event_time: Int,
    devices: Map(MacAddress, Device),
    bulbs: Map(MacAddress, Bulb),
    selected_groups: Set(Group),
    keypad: Keypad,
    socket: Socket,
    led_bus: Bus,
    sender: Sender(Msg),
  )
}

pub type Msg {
  LifxDiscoverIntervalElapsed
  LifxRefreshIntervalElapsed
  KeypadRefreshIntervalElapsed(Int)
  PacketReceived(packet: BitString, ip_address: IPAddress)
  InvalidPacketReceived
}

type Effect {
  SendPacket(packet: BitString, ip_address: IPAddress)
}

type Update =
  tuple(Model, List(Effect))

//
// Actor stuff
//
pub fn start_link(_any: a, _any: a) -> actor.ErlangStartResult {
  actor.Spec(init: init, init_timeout: 1000, loop: update)
  |> actor.start_spec()
  |> actor.to_erlang_start_result()
}

//
// Initialisation
//
const keypad_refresh_interval: Int = 15

const keypad_input_timeout: Int = 5_000

const lifx_refresh_interval: Int = 30_000

const lifx_discover_interval: Int = 120_000

fn init() -> InitResult(Model, Msg) {
  // Turn off the green LED on the RPI0 itself - it's annoying at night.
  onboard_led_off()

  // Open the SPI bus to communicate with LEDs
  assert Ok(spi_bus) = spi.open()

  // Open a gen_udp socket and set up a bare receiver to handle incoming messages
  assert Ok(udp_socket) = udp.socket_open()
  let udp_receiver =
    process.bare_message_receiver()
    |> process.map_receiver(fn(dyn) {
      case udp.decoder(dyn) {
        Ok(tup) ->
          PacketReceived(ip_address: pair.first(tup), packet: pair.second(tup))
        Error(_) -> InvalidPacketReceived
      }
    })

  // Get a channel for handling messages sent by the actor to itself  
  let tuple(sender, channel_receiver) = process.new_channel()

  // Merge the channel receiver and the udp receiver
  let receiver = process.merge_receiver(udp_receiver, channel_receiver)

  // Initialise the state and run any starting effects
  let model =
    Model(
      time: 0,
      last_key_event_time: 0,
      selected_groups: set.new(),
      devices: map.new(),
      bulbs: map.new(),
      keypad: keypad.init(),
      socket: udp_socket,
      led_bus: spi_bus,
      sender: sender,
    )

  // Start the clock for regular refreshes of the state
  process.send_after(
    sender,
    keypad_refresh_interval,
    KeypadRefreshIntervalElapsed(keypad_refresh_interval),
  )
  process.send_after(sender, 20_000, LifxRefreshIntervalElapsed)
  process.send_after(sender, 10_000, LifxDiscoverIntervalElapsed)

  Ready(model, option.Some(receiver))
}

fn onboard_led_off() -> Nil {
  let power = atom.create_from_string("power")
  nerves_leds_set("led0", [tuple(power, False)])
  Nil
}

external fn nerves_leds_set(String, List(tuple(Atom, Bool))) -> Atom =
  "Elixir.Nerves.Leds" "set"

//
// Update
//
fn update(msg: Msg, model: Model) -> Next(Model) {
  case msg {
    LifxDiscoverIntervalElapsed -> discover_devices(model)
    LifxRefreshIntervalElapsed -> refresh_devices(model)
    KeypadRefreshIntervalElapsed(tick_time) ->
      handle_key_events(model, tick_time)
    PacketReceived(packet, ip_address) ->
      handle_packet(model, packet, ip_address)
    InvalidPacketReceived -> Continue(model)
  }
}

fn handle_packet(
  model: Model,
  packet: BitString,
  ip_address: IPAddress,
) -> Next(Model) {
  let new_model = case incoming_msg.parse(packet, ip_address) {
    Ok(msg) ->
      case map.get(model.bulbs, msg.mac_address) {
        Ok(bulb_) ->
          Model(
            ..model,
            bulbs: bulb_
            |> bulb.update(msg)
            |> map.insert(model.bulbs, msg.mac_address, _),
          )
        Error(_) ->
          case map.get(model.devices, msg.mac_address) {
            Ok(device_) ->
              case device_
              |> device.update(msg)
              |> device.validate() {
                Ok(bulb_) ->
                  Model(
                    ..model,
                    bulbs: map.insert(model.bulbs, msg.mac_address, bulb_),
                  )
                Error(device_) ->
                  Model(
                    ..model,
                    devices: map.insert(model.devices, msg.mac_address, device_),
                  )
              }
            Error(_) ->
              Model(
                ..model,
                devices: map.insert(
                  model.devices,
                  msg.mac_address,
                  device.new(
                    msg.mac_address,
                    msg.ip_address,
                    port.from_int(56700),
                  ),
                ),
              )
          }
      }
    Error(_) -> model
  }
  Continue(new_model)
}

fn discover_devices(model: Model) -> Next(Model) {
  let _ =
    udp.socket_send(
      model.socket,
      ip_address.broadcast,
      outgoing_msg.get_service(),
    )
  process.send_after(
    model.sender,
    lifx_discover_interval,
    LifxDiscoverIntervalElapsed,
  )
  Continue(model)
}

fn refresh_devices(model: Model) -> Next(Model) {
  model.devices
  |> map.values
  |> list.map(fn(device_: Device) {
    let _ =
      udp.socket_send(
        model.socket,
        device_.ip_address,
        outgoing_msg.get_group(device_),
      )
    let _ =
      udp.socket_send(
        model.socket,
        device_.ip_address,
        outgoing_msg.get_location(device_),
      )
    let _ =
      udp.socket_send(
        model.socket,
        device_.ip_address,
        outgoing_msg.get_state(device_),
      )
    Nil
  })
  process.send_after(
    model.sender,
    lifx_refresh_interval,
    LifxRefreshIntervalElapsed,
  )
  Continue(model)
}

fn handle_key_events(model: Model, tick_time: Int) -> Next(Model) {
  let new_keypad = keypad.read(model.keypad)
  let key_events = keypad.diff(old: model.keypad, new: new_keypad)

  process.send_after(
    model.sender,
    keypad_refresh_interval,
    KeypadRefreshIntervalElapsed(keypad_refresh_interval),
  )

  case any_key_events_occurred_on_this_tick(key_events) {
    True -> {
      let model2 =
        model
        |> set_time(tick_time)
        |> set_keypad(new_keypad)
      case keypad_has_timed_out(model2) {
        True ->
          // Ignore the input, but turn the leds back on
          model2
          |> set_last_key_event_time()
          |> refresh_leds()
          |> Continue
        False ->
          // Process the input
          model2
          |> set_last_key_event_time()
          |> handle_keydowns(key_events.downs)
          |> run_effects()
          |> refresh_leds()
          |> Continue
      }
    }
    False -> {
      case keypad_timeout_occurred_on_this_tick(model, tick_time) {
        True -> {
          let _ = led.turn_off(model.led_bus)
          Nil
        }
        False -> Nil
      }
      model
      |> set_time(tick_time)
      |> Continue
    }
  }
}

fn keypad_has_timed_out(model: Model) -> Bool {
  model.time - model.last_key_event_time > keypad_input_timeout
}

fn set_last_key_event_time(model: Model) -> Model {
  Model(..model, last_key_event_time: model.time)
}

fn any_key_events_occurred_on_this_tick(key_events: keypad.Diff) -> Bool {
  list.length(key_events.ups) > 0 || list.length(key_events.downs) > 0
}

fn refresh_leds(model: Model) -> Model {
  let _ = led.refresh(model.keypad, model.selected_groups, model.led_bus)
  model
}

fn keypad_timeout_occurred_on_this_tick(model: Model, tick_time: Int) -> Bool {
  let timeout_at_previous_tick = model.time - model.last_key_event_time
  let timeout_at_current_tick =
    model.time + tick_time - model.last_key_event_time

  timeout_at_previous_tick <= keypad_input_timeout && timeout_at_current_tick > keypad_input_timeout
}

fn handle_keydowns(model: Model, keydowns: List(Button)) -> Update {
  list.fold(
    keydowns,
    tuple(model, []),
    fn(keydown, model_and_effects) {
      let tuple(old_model, old_effects) = model_and_effects
      let tuple(new_model, new_effects) = handle_keydown(old_model, keydown)
      tuple(new_model, list.append(old_effects, new_effects))
    },
  )
}

fn handle_keydown(model: Model, keydown: Button) -> Update {
  case keydown {
    button.ToggleGroup(g) -> handle_toggle_group(model, g)
    button.Power(p) -> handle_power(model, p)
    button.Temperature(t) -> handle_temperature(model, t)
    button.Brightness(b) -> handle_brightness(model, b)
    button.Select(s) -> handle_select(model, s)
  }
}

fn handle_toggle_group(model: Model, group: Group) -> Update {
  let new_selected_groups = toggle_set(model.selected_groups, group)
  tuple(Model(..model, selected_groups: new_selected_groups), [])
}

fn toggle_set(set_: Set(a), item: a) -> Set(a) {
  case set.contains(set_, item) {
    True -> set.delete(set_, item)
    False -> set.insert(set_, item)
  }
}

fn handle_power(model: Model, power: Power) -> Update {
  let updated_bulbs =
    model.bulbs
    |> map.filter(fn(_, bulb_: Bulb) {
      set.contains(model.selected_groups, bulb_.group)
    })
    |> map.map_values(fn(_, bulb_: Bulb) { bulb.set_power(bulb_, power) })

  let effects =
    updated_bulbs
    |> map.values
    |> list.map(fn(bulb_: Bulb) {
      SendPacket(
        ip_address: bulb_.ip_address,
        packet: outgoing_msg.set_power(bulb_),
      )
    })

  let new_bulbs = map.merge(model.bulbs, updated_bulbs)

  tuple(Model(..model, bulbs: new_bulbs), effects)
}

fn handle_temperature(model: Model, temperature_diff: button.UpDown) -> Update {
  let updated_bulbs =
    model.bulbs
    |> map.filter(fn(_, bulb_: Bulb) {
      set.contains(model.selected_groups, bulb_.group)
    })
    |> map.map_values(fn(_, bulb_: Bulb) {
      let increment = case temperature_diff {
        button.Up -> 0.2
        button.Down -> -0.2
      }
      let new_kelvin = kelvin.increment(bulb_.kelvin, increment)
      bulb.set_kelvin(bulb_, new_kelvin)
    })

  let effects =
    updated_bulbs
    |> map.values
    |> list.map(fn(bulb_: Bulb) {
      SendPacket(
        ip_address: bulb_.ip_address,
        packet: outgoing_msg.set_color(bulb_, 0),
      )
    })

  let new_bulbs = map.merge(model.bulbs, updated_bulbs)

  tuple(Model(..model, bulbs: new_bulbs), effects)
}

fn handle_brightness(model: Model, brightness_diff: button.UpDown) -> Update {
  let updated_bulbs =
    model.bulbs
    |> map.filter(fn(_, bulb_: Bulb) {
      set.contains(model.selected_groups, bulb_.group)
    })
    |> map.map_values(fn(_, bulb_: Bulb) {
      let increment = case brightness_diff {
        button.Up -> 0.2
        button.Down -> -0.2
      }
      let new_brightness = hsb.increment(bulb_.brightness, increment)
      bulb.set_brightness(bulb_, new_brightness)
    })

  let effects =
    updated_bulbs
    |> map.values
    |> list.map(fn(bulb_: Bulb) {
      SendPacket(
        ip_address: bulb_.ip_address,
        packet: outgoing_msg.set_color(bulb_, 0),
      )
    })

  let new_bulbs = map.merge(model.bulbs, updated_bulbs)

  tuple(Model(..model, bulbs: new_bulbs), effects)
}

fn handle_select(model: Model, select: button.AllNone) -> Update {
  tuple(Model(..model, selected_groups: case select {
        button.All -> group.all()
        button.None -> group.none()
      }), [])
}

fn run_effects(model_and_effects: Update) -> Model {
  let tuple(model, effects) = model_and_effects
  list.map(effects, fn(effect) { run_effect(effect, model) })
  model
}

fn run_effect(effect: Effect, model: Model) -> Nil {
  case effect {
    SendPacket(packet, ip_address) -> {
      let _ = udp.socket_send(model.socket, ip_address, packet)
      Nil
    }
  }
}

fn set_keypad(model: Model, keypad: Keypad) -> Model {
  Model(..model, keypad: keypad)
}

fn set_time(model: Model, tick_time: Int) -> Model {
  Model(..model, time: model.time + tick_time)
}
