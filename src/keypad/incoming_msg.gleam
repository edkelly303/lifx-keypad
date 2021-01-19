import gleam/result
import gleam/bit_string
import gleam/list
import gleam/io
import keypad/error.{ErrorType}
import keypad/power.{Off, On, Power}
import keypad/ip_address.{IPAddress}
import keypad/mac_address.{MacAddress}
import keypad/hsb.{Hsb}
import keypad/kelvin.{Kelvin}

const device_state_service_msg: Int = 3

const device_state_location_msg: Int = 50

const device_state_group_msg: Int = 53

const light_state_msg: Int = 107

pub type Payload {
  DeviceStateService(service: Int, port: Int)
  DeviceStateLocation(id: Int, label: String)
  DeviceStateGroup(id: Int, label: String)
  LightState(
    label: String,
    hue: Hsb,
    saturation: Hsb,
    brightness: Hsb,
    kelvin: Kelvin,
    power: Power,
  )
}

pub type IncomingMsg {
  IncomingMsg(ip_address: IPAddress, mac_address: MacAddress, payload: Payload)
}

external fn binary_to_list(BitString) -> List(Int) =
  "erlang" "binary_to_list"

external fn list_to_binary(List(Int)) -> BitString =
  "erlang" "list_to_binary"

fn label_from_binary(binary: BitString) -> Result(String, ErrorType) {
  binary
  |> binary_to_list()
  |> list.filter(fn(byte) { byte != 0 })
  |> list_to_binary()
  |> bit_string.to_string()
  |> result.map_error(fn(_) { error.LabelIsNotUTF8String })
}

fn parse_device_state_service_msg(
  payload: BitString,
) -> Result(Payload, ErrorType) {
  case payload {
    <<service:unsigned-little-int-size(8), port:unsigned-little-int-size(32)>> ->
      Ok(DeviceStateService(service: service, port: port))
    _ -> Error(error.FailedToParsePayload)
  }
}

fn parse_device_state_location_msg(
  payload: BitString,
) -> Result(Payload, ErrorType) {
  case payload {
    <<
      id:unsigned-little-int-size(128),
      label_binary:little-binary-unit(8)-size(32),
      _updated_at:unsigned-little-int-size(64),
    >> ->
      label_binary
      |> label_from_binary()
      |> result.then(fn(label) { Ok(DeviceStateLocation(id, label)) })
    _ -> Error(error.FailedToParsePayload)
  }
}

fn parse_device_state_group_msg(
  payload: BitString,
) -> Result(Payload, ErrorType) {
  case payload {
    <<
      id:unsigned-little-int-size(128),
      label_binary:little-binary-unit(8)-size(32),
      _updated_at:unsigned-little-int-size(64),
    >> ->
      label_binary
      |> label_from_binary()
      |> result.then(fn(label) { Ok(DeviceStateGroup(id, label)) })
    _ -> Error(error.FailedToParsePayload)
  }
}

fn parse_light_state_msg(payload: BitString) -> Result(Payload, ErrorType) {
  case payload {
    <<
      hue:unsigned-little-int-size(16),
      saturation:unsigned-little-int-size(16),
      brightness:unsigned-little-int-size(16),
      kelvin_:unsigned-little-int-size(16),
      _reserved:signed-little-int-size(16),
      power_:unsigned-little-int-size(16),
      label_binary:little-binary-unit(8)-size(32),
      _reserved:unsigned-little-int-size(64),
    >> ->
      label_from_binary(label_binary)
      |> result.then(fn(label) {
        Ok(LightState(
          hue: hsb.from_int(hue),
          saturation: hsb.from_int(saturation),
          brightness: hsb.from_int(brightness),
          kelvin: kelvin.from_int(kelvin_),
          power: power.from_int(power_),
          label: label,
        ))
      })
    _ -> Error(error.FailedToParsePayload)
  }
}

fn parse_payload(
  msg_type: Int,
  payload: BitString,
) -> Result(Payload, ErrorType) {
  case msg_type {
    n if n == device_state_service_msg ->
      parse_device_state_service_msg(payload)
    n if n == device_state_location_msg ->
      parse_device_state_location_msg(payload)
    n if n == device_state_group_msg -> parse_device_state_group_msg(payload)
    n if n == light_state_msg -> parse_light_state_msg(payload)
    n -> Error(error.UnknownMsgType(n))
  }
}

pub fn parse(
  packet: BitString,
  ip_address: IPAddress,
) -> Result(IncomingMsg, ErrorType) {
  case packet {
    <<
      //  frame header
      _size:unsigned-little-int-size(16),
      _frame_fields:unsigned-int-little-size(16),
      _source:unsigned-little-int-size(32),
      //  frame address header
      mac_addr:unsigned-int-little-size(64),
      _reserved:unsigned-int-little-size(48),
      _frame_address_fields:unsigned-int-little-size(16),
      //  protocol header
      _reserved:unsigned-int-little-size(64),
      msg_type:unsigned-int-little-size(16),
      _reserved:unsigned-int-little-size(16),
      //  payload
      payload_binary:little-binary,
    >> ->
      parse_payload(msg_type, payload_binary)
      |> result.map(fn(payload) {
        IncomingMsg(
          mac_address: mac_address.from_int(mac_addr),
          ip_address: ip_address,
          payload: payload,
        )
      })
    _ -> Error(error.FailedToParseHeader)
  }
}
