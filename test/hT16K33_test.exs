defmodule HT16K33Test do
  use ExUnit.Case

  test "Returns a nice decimal for a space" do
    assert HT16K33.character_for(' ')
           |> HT16K33.with_decimal_point() == <<0x00, 0x40>>
  end
end
