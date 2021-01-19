import gleam/set.{Set}
import gleam/io

pub type Group {
  Bedroom
  DiningRoom
  LivingRoom
  Study
}

pub fn all() -> Set(Group) {
  set.from_list([Bedroom, DiningRoom, LivingRoom, Study])
}

pub fn none() -> Set(Group) {
  set.new()
}

pub fn to_string(group: Group) -> String {
  case group {
    Bedroom -> "Bedroom"
    DiningRoom -> "Dining Room"
    LivingRoom -> "Living Room"
    Study -> "Study"
  }
}

pub type InvalidGroup {
  InvalidGroup
}

pub fn from_string(string: String) -> Result(Group, InvalidGroup) {
  let _ = io.debug("Parsed group name: ")
  let _ = io.debug(string)
  case string {
    "Bedroom" -> Ok(Bedroom)
    "Dining Room" -> Ok(DiningRoom)
    "Living Room" -> Ok(LivingRoom)
    "Ed's Study" -> Ok(Study)
    _ -> Error(InvalidGroup)
  }
}
