pub opaque type Port {
  Port(Int)
}

pub fn from_int(int: Int) -> Port {
  Port(int)
}

pub fn to_int(port: Port) -> Int {
  case port {
    Port(int) -> int
  }
}
