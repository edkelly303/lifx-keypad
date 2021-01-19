import keypad/power
import keypad/group.{Group}
import keypad/location.{Location}
import keypad/ip_address.{IPAddress}
import keypad/mac_address.{MacAddress}
import keypad/port.{Port}
import keypad/power.{Power}
import keypad/incoming_msg.{
  DeviceStateGroup, DeviceStateLocation, DeviceStateService, IncomingMsg, LightState,
}
import keypad/hsb.{Hsb}
import keypad/kelvin.{Kelvin}

pub type Bulb {
  Bulb(
    label: String,
    hue: Hsb,
    saturation: Hsb,
    brightness: Hsb,
    kelvin: Kelvin,
    power: Power,
    group: Group,
    location: Location,
    mac_address: MacAddress,
    ip_address: IPAddress,
    port: Port,
  )
}

pub fn update(bulb: Bulb, incoming_msg: IncomingMsg) -> Bulb {
  case incoming_msg.payload {
    DeviceStateService(_service, port_) ->
      Bulb(..bulb, port: port.from_int(port_))

    DeviceStateLocation(id, label) ->
      Bulb(..bulb, location: Location(id: id, label: label))

    DeviceStateGroup(_id, label) ->
      Bulb(..bulb, group: case group.from_string(label) {
          Ok(group) -> group
          Error(_) -> bulb.group
        })

    LightState(label, hue, saturation, brightness, kelvin, power) ->
      Bulb(
        ..bulb,
        label: label,
        hue: hue,
        saturation: saturation,
        brightness: brightness,
        kelvin: kelvin,
        power: power,
      )
    _ -> bulb
  }
}

pub fn set_brightness(bulb: Bulb, brightness: Hsb) {
  Bulb(..bulb, brightness: brightness)
}

pub fn set_kelvin(bulb: Bulb, kelvin: Kelvin) {
  Bulb(..bulb, kelvin: kelvin)
}

pub fn set_power(bulb: Bulb, power: Power) {
  Bulb(..bulb, power: power)
}
