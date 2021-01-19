import keypad/group.{Group}
import keypad/location.{Location}
import keypad/ip_address.{IPAddress}
import keypad/mac_address.{MacAddress}
import keypad/error
import keypad/bulb.{Bulb}
import keypad/port.{Port}
import keypad/power.{Power}
import keypad/incoming_msg.{
  DeviceStateGroup, DeviceStateLocation, DeviceStateService, IncomingMsg, LightState,
}
import keypad/hsb.{Hsb}
import keypad/kelvin.{Kelvin}
import gleam/result

pub type Device {
  Device(
    bulb_state_result: Result(BulbState, error.ErrorType),
    group_result: Result(Group, error.ErrorType),
    location_result: Result(Location, error.ErrorType),
    mac_address: MacAddress,
    ip_address: IPAddress,
    port: Port,
  )
}

pub type BulbState {
  BulbState(
    label: String,
    hue: Hsb,
    saturation: Hsb,
    brightness: Hsb,
    kelvin: Kelvin,
    power: Power,
  )
}

pub fn new(mac_address: MacAddress, ip_address: IPAddress, port: Port) -> Device {
  Device(
    bulb_state_result: Error(error.DeviceHasMissingData),
    group_result: Error(error.DeviceHasMissingData),
    location_result: Error(error.DeviceHasMissingData),
    mac_address: mac_address,
    ip_address: ip_address,
    port: port,
  )
}

pub fn update(device: Device, incoming_msg: IncomingMsg) -> Device {
  case incoming_msg.payload {
    DeviceStateLocation(id, label) ->
      Device(..device, location_result: Ok(Location(id: id, label: label)))

    DeviceStateGroup(_id, label) ->
      Device(
        ..device,
        group_result: group.from_string(label)
        |> result.map_error(fn(_) { error.DeviceHasMissingData }),
      )
    LightState(label, hue, saturation, brightness, kelvin, power) ->
      Device(
        ..device,
        bulb_state_result: Ok(BulbState(
          label: label,
          hue: hue,
          saturation: saturation,
          brightness: brightness,
          kelvin: kelvin,
          power: power,
        )),
      )
    _ -> device
  }
}

pub fn validate(device: Device) -> Result(Bulb, Device) {
  try state =
    device.bulb_state_result
    |> result.map_error(fn(_) { device })
  try group =
    device.group_result
    |> result.map_error(fn(_) { device })
  try location =
    device.location_result
    |> result.map_error(fn(_) { device })
  Ok(Bulb(
    label: state.label,
    hue: state.hue,
    saturation: state.saturation,
    brightness: state.brightness,
    kelvin: state.kelvin,
    power: state.power,
    group: group,
    location: location,
    mac_address: device.mac_address,
    ip_address: device.ip_address,
    port: device.port,
  ))
}
