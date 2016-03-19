defmodule CoAP.Header do
  use CoAP.Codes

  defstruct version: @version, type: 0, code_class: 0, code_detail: 0, message_id: 0, token: <<>>

end
