defmodule HT16K33 do
  @moduledoc """
  API for working with HT16K33 14-segment display backpacks
  """
  use Bitwise
  alias Circuits.I2C

  @type backpack_state :: %{
          ref: I2C.bus(),
          addr: integer
        }

  @i2c_code "i2c-1"
  # Default address for HT16K33 - up to 0x77
  @addr 0x70

  @doc """
  Returns a state map with nil I2C ref, i2c bus code "i2c-1" and address 0x70
  Generally, prefer `init`
  """
  def default_state do
    %{
      ref: nil,
      addr: @addr
    }
  end

  @doc """
  Initializes an HT16K33 at `addr` and `i2c_code` and returns state

  ## Parameters
  	- i2c_code: a string representing an i2c bus code, default "i2c-1"
  	- addr: a number indicating the i2c address, default 0x70
  """
  @spec init(String.t(), integer) :: backpack_state
  def init(i2c_code \\ @i2c_code, addr \\ @addr) do
    {:ok, ref} = I2C.open(i2c_code)
    I2C.write(ref, addr, <<0x21>>)
    %{default_state() | ref: ref, addr: addr}
  end

  @doc """
  Deinitializes the HT16K33 at `state.addr` referenced by `state.ref` and 
  closes `state.ref`

  ## Parameters
  	- state: an HT16K33 state
  """
  @spec deinit(backpack_state) :: :ok
  def deinit(state) do
    I2C.write(state[:ref], state[:addr], <<0x20>>)
    I2C.close(state[:ref])
  end

  @doc """
  Takes `on` as new display power setting

  ## Parameters
  	- state: an HT16K33 state
  	- on: a boolean, defaulting to true to turn power on
  """
  @spec power(backpack_state, boolean) :: backpack_state
  def power(state, on \\ true) do
    I2C.write(state[:ref], state[:addr], <<0x80 ||| if(on, do: 0x01, else: 0x00)>>)
    state
  end

  @doc """
  Clears display (extinguishes all segments)

  ## Parameters
  	- state: an HT16K33 state
  """
  @spec clear(backpack_state) :: backpack_state
  def clear(state) do
    I2C.write(state[:ref], state[:addr], <<0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00>>)
    state
  end

  @doc """
  Fills a display (illuminates all segments)

  ## Parameters
  	- state: an HT16K33 state
  """
  @spec fill(backpack_state) :: backpack_state
  def fill(state) do
    I2C.write(state[:ref], state[:addr], <<0x00, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF>>)
    state
  end

  @doc """
  Sets display to blink at hz rate

  ## Parameters
  	- state: an HT16K33 state
  	- hz: blink rate, valid options are 0.5, 1.0, 2.0, default is no blink, which is equivalent to `power(state, true)`
  """
  @spec blink(backpack_state, float) :: backpack_state
  def blink(state, hz) when hz == 0.5 do
    I2C.write(state[:ref], state[:addr], <<0x87>>)
    state
  end

  def blink(state, hz) when hz == 1.0 do
    I2C.write(state[:ref], state[:addr], <<0x85>>)
    state
  end

  def blink(state, hz) when hz == 2.0 do
    I2C.write(state[:ref], state[:addr], <<0x83>>)
    state
  end

  def blink(state, _hz) do
    I2C.write(state[:ref], state[:addr], <<0x81>>)
    state
  end

  @doc """
  Sets display brightness level

  ## Parameters
  	- state: an HT16K33 state
  	- brightness: brightness level, valid [0, 16)
  """
  @spec radiate(backpack_state, non_neg_integer) :: backpack_state
  def radiate(state, brightness) when 0 <= brightness and brightness < 16 do
    I2C.write(state[:ref], state[:addr], <<0xE0 ||| brightness>>)
    state
  end

  def radiate(state, _brightness), do: state

  @doc """
  Write a character to a position

  ## Parameters
  	- state: an HT16K33 state
  	- pos: on which 14-segment display to render the character, [0, 3]
  	- code: bitstream code to output
  """
  @spec write_char_to(backpack_state, 0..3, bitstring) :: backpack_state
  def write_char_to(state, pos, code) when 0 <= pos and pos < 4 do
    I2C.write(state[:ref], state[:addr], <<pos * 2>> <> code)
    state
  end

  def write_char_to(state, _pos, _code), do: state

  @doc """
  Write a string to a position

  ## Parameters
  	- state: an HT16K33 state
  	- pos: on which 14-segment display to start rendering the str, [0, 4-length(str)]
  	- str: list of chars 
  """
  @spec write_string_to(backpack_state, 0..3, list(char)) :: backpack_state
  def write_string_to(state, pos, str) when length(str) + pos <= 4 and 0 <= pos do
    I2C.write(
      state[:ref],
      state[:addr],
      <<pos * 2>> <> List.foldl(str, <<>>, fn x, acc -> acc <> character_for(x) end)
    )

    state
  end
  def write_string_to(state, _pos, _str), do: state

  @doc """
  Add a decimal point to a character bitstream value

  ## Parameters
  	- char: a bitstream character
  """
  @spec with_decimal_point(bitstring) :: bitstring
  def with_decimal_point(char) do
    <<f, s>> = char
    <<f, s ||| 0x40>>
  end

  @doc """
  Get a bitstream value for a character `char`

  ## Parameters
  	- char: a character, currently digits and ['%', 'C', 'H', 'E', 'T'] are supported, and unsupported characters are blank
  """
  @spec character_for(char) :: bitstring
  def character_for(char) do
    case char do
      '1' -> <<0b00000110, 0b00000000>>
      '2' -> <<0b11011011, 0b00000000>>
      '3' -> <<0b11001111, 0b00000000>>
      '4' -> <<0b11100110, 0b00000000>>
      '5' -> <<0b11101101, 0b00000000>>
      '6' -> <<0b11111101, 0b00000000>>
      '7' -> <<0b00000001, 0b00001100>>
      '8' -> <<0b11111111, 0b00000000>>
      '9' -> <<0b11100111, 0b00000000>>
      '0' -> <<0b00111111, 0b00000000>>
      '%' -> <<0b11100100, 0b00011110>>
      'A' -> <<0b11110111, 0b00000000>>
      'B' -> <<0b01111001, 0b00100100>>
      'C' -> <<0b00111001, 0b00000000>>
      'D' -> <<0b00110000, 0b00001001>>
      'E' -> <<0b11111001, 0b00000000>>
      'F' -> <<0b11110001, 0b00000000>>
      'G' -> <<0b10111101, 0b00100000>>
      'H' -> <<0b11110110, 0b00000000>>
      'I' -> <<0b00001001, 0b00010010>>
      'J' -> <<0b00001110, 0b00001000>>
      'K' -> <<0b01110000, 0b00100100>>
      'L' -> <<0b00111000, 0b00000000>>
      'M' -> <<0b00110110, 0b00000101>>
      'N' -> <<0b00110110, 0b00100001>>
      'O' -> <<0b00111111, 0b00000000>>
      'P' -> <<0b11110011, 0b00000000>>
      'Q' -> <<0b00111111, 0b00100000>>
      'R' -> <<0b11110011, 0b00100000>>
      'S' -> <<0b00001001, 0b00100001>>
      'T' -> <<0b00000001, 0b00010010>>
      'U' -> <<0b00111110, 0b00000000>>
      'V' -> <<0b00110000, 0b00001100>>
      'W' -> <<0b00110110, 0b00101000>>
      'X' -> <<0b00000000, 0b00101101>>
      'Y' -> <<0b00000000, 0b00010101>>
      'Z' -> <<0b00001001, 0b00001100>>
      'a' -> <<0b11110111, 0b00000000>>
      'b' -> <<0b01111001, 0b00100100>>
      'c' -> <<0b00111001, 0b00000000>>
      'd' -> <<0b00110000, 0b00001001>>
      'e' -> <<0b11111001, 0b00000000>>
      'f' -> <<0b11110001, 0b00000000>>
      'g' -> <<0b10111101, 0b00100000>>
      'h' -> <<0b11110110, 0b00000000>>
      'i' -> <<0b00001001, 0b00010010>>
      'j' -> <<0b00001110, 0b00001000>>
      'k' -> <<0b01110000, 0b00100100>>
      'l' -> <<0b00111000, 0b00000000>>
      'm' -> <<0b00110110, 0b00000101>>
      'n' -> <<0b00110110, 0b00100001>>
      'o' -> <<0b00111111, 0b00000000>>
      'p' -> <<0b11110011, 0b00000000>>
      'q' -> <<0b00111111, 0b00100000>>
      'r' -> <<0b11110011, 0b00100000>>
      's' -> <<0b00001001, 0b00100001>>
      't' -> <<0b00000001, 0b00010010>>
      'u' -> <<0b00111110, 0b00000000>>
      'v' -> <<0b00110000, 0b00001100>>
      'w' -> <<0b00110110, 0b00101000>>
      'x' -> <<0b00000000, 0b00101101>>
      'y' -> <<0b00000000, 0b00010101>>
      'z' -> <<0b00001001, 0b00001100>>
      ' ' -> <<0b00000000, 0b00000000>>
      _ -> <<0b00000000, 0b00000000>>
    end
  end
end
