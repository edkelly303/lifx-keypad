import gleam/int

pub opaque type MacAddress {
  MacAddress(Int)
}

pub fn any() -> MacAddress {
  from_int(0)
}

pub fn from_int(int: Int) -> MacAddress {
  MacAddress(int)
}

pub fn to_int(mac_address: MacAddress) -> Int {
  case mac_address {
    MacAddress(int) -> int
  }
}

pub fn to_string(mac_address: MacAddress) -> String {
  mac_address
  |> to_int
  |> int.to_string
}
