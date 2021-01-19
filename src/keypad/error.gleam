import gleam/string
import gleam/int

pub type ErrorType {
  FailedToParseHeader
  UnknownMsgType(Int)
  FailedToParsePayload
  LabelIsNotUTF8String
  DeviceHasMissingData
  NotABulb
}

pub fn to_string(error: ErrorType) -> String {
  case error {
    FailedToParseHeader -> "failed to parse packet header"
    UnknownMsgType(n) ->
      string.append("unknown message type: ", int.to_string(n))
    FailedToParsePayload -> "failed to parse packet payload"
    LabelIsNotUTF8String -> "label is not UTF8 string"
    DeviceHasMissingData -> "device has missing data"
    NotABulb -> "device is not a bulb"
  }
}
