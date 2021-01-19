import gleam/bit_string.{BitString}
import gleam/dynamic.{Dynamic}
import gleam/result

pub external type Bus

pub type ErrorType {
  FailedToOpenSpiBus
  FailedToTransferData
}

pub fn open() -> Result(Bus, ErrorType) {
  circuits_spi_open("spidev0.0")
  |> result.map_error(fn(_) { FailedToOpenSpiBus })
}

external fn circuits_spi_open(String) -> Result(Bus, Dynamic) =
  "circuits_spi" "open"

pub fn transfer(bus: Bus, data: BitString) -> Result(BitString, ErrorType) {
  circuits_spi_transfer(bus, data)
  |> result.map_error(fn(_) { FailedToTransferData })
}

external fn circuits_spi_transfer(
  bus: Bus,
  data: BitString,
) -> Result(BitString, Dynamic) =
  "circuits_spi" "transfer"
