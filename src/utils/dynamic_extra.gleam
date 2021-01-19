import gleam/result
import gleam/atom
import gleam/dynamic.{Dynamic}
import gleam/pair
import gleam/string

pub fn ok_atom_or_error_reason_tuple(
  data: Dynamic,
) -> Result(Result(Nil, Dynamic), String) {
  case ok_decoder(data) {
    Ok(_) -> Ok(Ok(Nil))
    Error(_) ->
      case error_reason_tuple_decoder(data) {
        Ok(dynamic) -> Ok(Error(dynamic))
        Error(e) -> Error(e)
      }
  }
}

// HELPERS
fn ok_decoder(data: Dynamic) -> Result(Nil, String) {
  specific_atom_decoder(data, "ok")
}

fn error_reason_tuple_decoder(data: Dynamic) -> Result(Dynamic, String) {
  data
  |> dynamic.typed_tuple2(first: error_atom_decoder, second: fn(a) { Ok(a) })
  |> result.map(pair.second)
}

fn error_atom_decoder(data: Dynamic) -> Result(Nil, String) {
  specific_atom_decoder(data, "error")
}

fn specific_atom_decoder(data: Dynamic, match: String) -> Result(Nil, String) {
  data
  |> dynamic.atom
  |> result.then(fn(atom_) {
    case atom.to_string(atom_) {
      str if str == match -> Ok(Nil)
      _ -> Error("")
    }
  })
}
