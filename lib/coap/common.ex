defmodule CoAP.Common do

  defmacro __using__(_) do
    quote do
      @payload_marker 0xff
      @extended_option_1_byte 13
      @extended_option_2_bytes 269
    end
  end

end
