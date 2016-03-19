defmodule CoAP.Message do
  use CoAP.Codes

  defstruct header: nil, options: [], payload: <<>>

  def sort_options(msg) do
    update_in(msg.options, &Enum.sort_by(&1, fn opt -> opt.number end))
  end

  def empty?(%CoAP.Message{header: header}) do
    CoAP.Header.empty?(header)
  end

  def type(%CoAP.Message{header: header}) do
    CoAP.Header.type(header)
  end

  def class(%CoAP.Message{header: header}) do
    CoAP.Header.class(header)
  end

  def method(%CoAP.Message{header: header}) do
    CoAP.Header.method(header)
  end

  def code(%CoAP.Message{header: header}) do
    CoAP.Header.code(header)
  end

  def ack(msg) do
    {code_class, code_detail} = @responses_reverse[:empty]
    %CoAP.Message{
      header: %CoAP.Header{
        version: @version,
        type: @types_reverse[:acknowledgement],
        code_class: code_class,
        code_detail: code_detail,
        message_id: msg.header.message_id,
        token: msg.header.token
      }
    }
  end

end
