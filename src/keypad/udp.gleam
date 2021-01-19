import gleam/atom.{Atom}
import gleam/dynamic.{Dynamic}
import gleam/list
import gleam/result
import utils/dynamic_extra
import keypad/ip_address.{IPAddress}

//
// Public API
//
pub external type Socket

pub fn decoder(dyn: Dynamic) -> Result(tuple(IPAddress, BitString), String) {
  let ip_result =
    dynamic.element(dyn, 2)
    |> result.then(ip_address.decoder)
  let packet_result =
    dynamic.element(dyn, 4)
    |> result.then(dynamic.bit_string)
  case ip_result, packet_result {
    Ok(ip_address_), Ok(packet) -> Ok(tuple(ip_address_, packet))
    _, _ -> Error("Failed to decode udp response")
  }
}

pub fn socket_open() -> Result(Socket, Atom) {
  gen_udp_open(56700, gen_udp_options())
}

pub fn socket_send(
  socket: Socket,
  ip_address: IPAddress,
  packet: BitString,
) -> Result(Nil, Nil) {
  assert Ok(decoded_result) =
    gen_udp_send(socket, ip_address, 56700, packet)
    |> dynamic_extra.ok_atom_or_error_reason_tuple
  decoded_result
  |> result.map_error(fn(_) { Nil })
}

//
// Internal stuff
//
external fn gen_udp_open(Int, List(tuple(Atom, Atom))) -> Result(Socket, Atom) =
  "gen_udp" "open"

fn gen_udp_options() -> List(tuple(Atom, Atom)) {
  [tuple("mode", "binary"), tuple("active", "true"), tuple("broadcast", "true")]
  |> list.map(fn(tup) {
    let tuple(k, v) = tup
    tuple(atom.create_from_string(k), atom.create_from_string(v))
  })
}

external fn gen_udp_send(Socket, IPAddress, Int, BitString) -> Dynamic =
  "gen_udp" "send"
