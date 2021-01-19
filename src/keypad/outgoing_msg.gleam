import gleam/bit_string.{BitString}
import gleam/bit_builder
import gleam/bool
import gleam/list
import keypad/power.{Power}
import keypad/mac_address.{MacAddress}
import keypad/bulb.{Bulb}
import keypad/device.{Device}
import keypad/hsb.{Hsb}
import keypad/kelvin.{Kelvin}

//
// Public API
//
pub fn get_service() -> BitString {
  build_packet(GetService, mac_address.any())
}

pub fn get_state(device_: Device) -> BitString {
  build_packet(GetState, device_.mac_address)
}

pub fn get_group(device_: Device) -> BitString {
  build_packet(GetGroup, device_.mac_address)
}

pub fn get_location(device_: Device) -> BitString {
  build_packet(GetLocation, device_.mac_address)
}

pub fn set_color(bulb: Bulb, duration: Int) -> BitString {
  build_packet(
    SetColor(
      hue: bulb.hue,
      saturation: bulb.saturation,
      brightness: bulb.brightness,
      kelvin: bulb.kelvin,
      duration: duration,
    ),
    bulb.mac_address,
  )
}

pub fn set_power(bulb: Bulb) -> BitString {
  build_packet(SetPower(power: bulb.power), bulb.mac_address)
}

//
// Internals
//
type OutgoingMsg {
  GetService
  GetState
  GetGroup
  GetLocation
  SetPower(power: Power)
  SetColor(
    hue: Hsb,
    saturation: Hsb,
    brightness: Hsb,
    kelvin: Kelvin,
    duration: Int,
  )
}

// source is an ID for the switch, we can pick whatever number we want
// should probably include this in config instead of hardcoding it,
// especially if we ever have more than one switch
const source: Int = 101

// frame header size = (16 + 12 + 1 + 1 + 2 + 32) / 8
// we can calculate the size of the other headers and the payload dynamically
const frame_header_size: Int = 8

// give the msg_type codes some nice, human-readable names
const get_service_msg: Int = 2

const get_state_msg: Int = 101

const get_group_msg: Int = 51

const get_location_msg: Int = 48

const set_color_msg: Int = 102

const set_power_msg: Int = 21

fn build_packet(msg: OutgoingMsg, mac_address: MacAddress) -> BitString {
  let msg_type = to_msg_type(msg)

  let header =
    build_header(
      mac_address: mac_address,
      needs_acknowledgement: False,
      needs_response: msg_type != set_color_msg,
      sequence: 0,
      msg_type: msg_type,
    )

  let payload = build_payload(msg)

  let packet_size =
    2 + bit_string.byte_size(header) + bit_string.byte_size(payload)

  <<packet_size:unsigned-little-int-size(16)>>
  |> bit_builder.from_bit_string()
  |> bit_builder.append(header)
  |> bit_builder.append(payload)
  |> bit_builder.to_bit_string()
}

fn build_set_power_payload(p: Power) -> BitString {
  let power_int = power.to_int(p)
  <<power_int:unsigned-little-int-size(16)>>
}

fn build_set_color_payload(
  hue: Hsb,
  saturation: Hsb,
  brightness: Hsb,
  kelvin_: Kelvin,
  millis: Int,
) -> BitString {
  <<
    0:unsigned-little-int-size(8),
    hsb.to_int(hue):unsigned-little-int-size(16),
    hsb.to_int(saturation):unsigned-little-int-size(16),
    hsb.to_int(brightness):unsigned-little-int-size(16),
    kelvin.to_int(kelvin_):unsigned-little-int-size(16),
    millis:unsigned-little-int-size(32),
  >>
}

fn build_payload(msg: OutgoingMsg) -> BitString {
  case msg {
    SetPower(power) -> build_set_power_payload(power)
    SetColor(hue, saturation, brightness, kelvin, millis) ->
      build_set_color_payload(hue, saturation, brightness, kelvin, millis)
    _ -> <<>>
  }
}

fn to_msg_type(msg: OutgoingMsg) -> Int {
  case msg {
    GetService -> get_service_msg
    GetState(..) -> get_state_msg
    GetGroup(..) -> get_group_msg
    GetLocation(..) -> get_location_msg
    SetColor(..) -> set_color_msg
    SetPower(..) -> set_power_msg
  }
}

fn build_header(
  mac_address mac_addr: MacAddress,
  needs_acknowledgement ack_required: Bool,
  needs_response res_required: Bool,
  sequence sequence: Int,
  msg_type msg_type: Int,
) {
  let tagged = case mac_addr == mac_address.any() {
    True -> 1
    False -> 0
  }
  let ack = bool.to_int(ack_required)
  let res = bool.to_int(res_required)
  let origin = 0
  let addressable = 1
  let protocol = 1024
  let source = 101
  let reserved = 0
  let target = mac_address.to_int(mac_addr)
  let otap =
    reverse_bits(<<
      origin:unsigned-int-size(2),
      tagged:unsigned-int-size(1),
      addressable:unsigned-int-size(1),
      protocol:unsigned-int-size(12),
    >>)
  let rar =
    reverse_bits(<<
      reserved:unsigned-int-size(6),
      ack:unsigned-int-size(1),
      res:unsigned-int-size(1),
    >>)
  <<
    otap:bit_string-size(16),
    source:unsigned-little-int-size(32),
    target:unsigned-little-int-size(64),
    reserved:unsigned-little-int-size(48),
    rar:bit_string-size(8),
    sequence:unsigned-little-int-size(8),
    reserved:unsigned-little-int-size(64),
    msg_type:unsigned-little-int-size(16),
    reserved:unsigned-little-int-size(16),
  >>
}

external fn binary_to_list(BitString) -> List(Int) =
  "erlang" "binary_to_list"

external fn list_to_binary(List(Int)) -> BitString =
  "erlang" "list_to_binary"

fn reverse_bits(bits: BitString) -> BitString {
  bits
  |> binary_to_list
  |> list.reverse
  |> list_to_binary
}
