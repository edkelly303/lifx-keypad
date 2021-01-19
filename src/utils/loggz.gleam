import gleam/atom.{Atom}

type Level {
  Emergency
  Alert
  Critical
  Error
  Warning
  Notice
  Info
  Debug
}

pub fn debug(string: String) -> Result(Nil, Nil) {
  let _ok_atom = log(Debug, string)
  Ok(Nil)
}

pub fn info(string: String) -> Result(Nil, Nil) {
  let _ok_atom = log(Info, string)
  Ok(Nil)
}

pub fn error(string: String) -> Result(Nil, Nil) {
  let _ok_atom = log(Error, string)
  Ok(Nil)
}

external fn log(level: Level, string: String) -> Atom =
  "logger" "log"
