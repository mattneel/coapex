defmodule CoAP.Server.State do

 defstruct udp: nil, inner_state: nil, module: :none

end

defmodule CoAP.Server.Adapter do
  use GenServer
  alias CoAP.Server.State

  def init({module, inner_args, opts}) do
    case UDP.start_link(port: opts[:port] || 3535, handlers: []) do
      {:ok, udp} ->
        UDP.listen(udp)
        state = %State{udp: udp, module: module}
        inner_init(state, inner_args)
      error ->
        error
    end
  end

  def handle_cast({:message, msg, from}, state) do
    case CoAP.Message.type(msg) do
      :confirmable ->
        inner_call state, msg, from, state.module.handle_confirmable(msg, from, state.inner_state)
      _ ->
        inner_cast state, state.module.handle_other(msg, from, state.inner_state)
    end
  end

  def handle_cast({:invalid, error, from}, state) do
    inner_cast state, state.module.handle_invalid(error, from, state)
  end

  def handle_info({:datagram, {_udp, address, port, data}}, state) do
    from = {address, port}
    try do
      msg = CoAP.Parser.parse(data)
      GenServer.cast(self, {:message, msg, from})
    rescue
      e -> GenServer.cast(self, {:invalid, e, from})
    end
    {:noreply, state}
  end

  def handle_info(info, state) do
    inner_cast state, state.module.handle_info(info, state.inner_state)
  end

  # it has to return a message to a cast
  defp inner_call(state, msg, from, update) do
    #TODO copy token from original msg, if missing
    case update do
      {:reply, reply, new_inner_state} ->
        udp_send(state.udp, from, reply)
        {:noreply, update_state(state, new_inner_state)}
      {:reply, reply, new_inner_state, timeout} ->
        udp_send(state.udp, from, reply)
        {:noreply, update_state(state, new_inner_state), timeout}
      {:noreply, new_inner_state} ->
        udp_send(state.udp, from, CoAP.Message.ack(msg))
        {:noreply, update_state(state, new_inner_state)}
      {:noreply, new_inner_state, timeout} ->
        udp_send(state.udp, from, CoAP.Message.ack(msg))
        {:noreply, update_state(state, new_inner_state), timeout}
      {:stop, reason, reply, new_inner_state} ->
        udp_send(state.udp, from, CoAP.Message.ack(msg))
        {:stop, reason, reply, new_inner_state}
      {:stop, reason, new_inner_state} ->
        udp_send(state.udp, from, CoAP.Message.ack(msg))
        {:stop, reason, update_state(state, new_inner_state)}
    end
  end

  defp inner_cast(state, update) do
    case update do
      {:noreply, new_inner_state} ->
        {:noreply, update_state(state, new_inner_state)}
      {:noreply, new_inner_state, timeout} ->
        {:noreply, update_state(state, new_inner_state), timeout}
      {:stop, reason, new_inner_state} ->
        {:stop, reason, update_state(state, new_inner_state)}
    end
  end

  def terminate(reason, state) do
    state.module.terminate(reason, state.inner_state)
  end

  def code_change(old_vsn, state, extra) do
    case state.module.code_change(old_vsn, state, extra) do
      {:ok, new_inner_state} ->
        {:ok, update_state(state, new_inner_state)}
      other ->
        other
    end
  end

  defp inner_init(state, inner_args) do
    case state.module.init(inner_args) do
      {:ok, inner_state} ->
        {:ok, update_state(state, inner_state)}
      {:ok, inner_state, timeout} ->
        {:ok, update_state(state, inner_state), timeout}
      other ->
        other
    end
  end

  defp udp_send(udp, {from_addr, from_port}, response) do
    try do
      data = CoAP.Serializer.serialize(response)
      case UDP.send(udp, from_addr, from_port, data) do
        :ok -> {}#TODO
        {:error, _reason} -> {}#TODO handle_invalid
      end
    rescue
      _e -> {}#TODO handle_invalid
    end
  end

  defp update_state(state, new_inner_state) do
    %{state | inner_state: new_inner_state}
  end

end

defmodule CoAP.Server do

  defmacro __using__(_) do
    quote do
      @behaviour CoAP.Server
    end
  end

  def start_link(module, args, opts \\ []) do
    GenServer.start_link(CoAP.Server.Adapter, {module, args, opts})
  end

  @type sender :: {:inet.ip_address | :inet.hostname, :inet.port_number}

  @callback init(args :: term) ::
    {:ok, state} |
    {:ok, state, timeout | :hibernate} |
    :ignore |
    {:stop, reason :: any} when state: any

  @callback handle_confirmable(message :: CoAP.Message.t, from :: sender, state :: term) ::
    {:reply, reply, new_state} |
    {:reply, reply, new_state, timeout | :hibernate} | #TODO {:reply_async, _}
    {:noreply, new_state} |
    {:noreply, new_state, timeout | :hibernate} |
    {:stop, reason, reply, new_state} |
    {:stop, reason, new_state} when reply: term, new_state: term, reason: term

  @callback handle_other(message :: CoAP.Message.t, from :: sender, state :: term) ::
    {:noreply, new_state} |
    {:noreply, new_state, timeout | :hibernate} |
    {:stop, reason :: term, new_state} when new_state: term

  @callback handle_invalid(error :: term, from :: sender, state :: term) ::
    {:noreply, new_state} |
    {:noreply, new_state, timeout | :hibernate} |
    {:stop, reason :: term, new_state} when new_state: term

  @callback handle_info(info :: :timeout | term, state :: term) ::
    {:noreply, new_state} |
    {:noreply, new_state, timeout | :hibernate} |
    {:stop, reason :: term, new_state} when new_state: term

  @callback terminate(reason, state :: term) ::
    term when reason: :normal | :shutdown | {:shutdown, term} | term

  @callback code_change(old_vsn, state :: term, extra :: term) ::
    {:ok, new_state :: term} |
    {:error, reason :: term} when old_vsn: term | {:down, term}

  # {:reply, _}
  # {:noreply, _}
  # {:reply_async , _}

end


defmodule AServer do
  use CoAP.Server

  def start_link do
    CoAP.Server.start_link(__MODULE__, [])
  end

  def init([]) do
    IO.puts "Server starting..."
    {:ok, :nada}
  end

  def handle_confirmable(message, from, :nada) do
    IO.puts "Received from #{inspect from} confirmable #{inspect message}"
    {:noreply, :nada}
  end

  def handle_other(message, from, :nada) do
    IO.puts "Received from #{inspect from} #{inspect message}"
    {:noreply, :nada}
  end

  def handle_invalid(error, from, :nada) do
    IO.puts("Error #{inspect error} from #{inspect from}")
    {:noreply, :nada}
  end

  def handle_info(info, :nada) do
    IO.puts("Info #{inspect info}")
    {:noreply, :nada}
  end

  def terminate(reason, :nada) do
    IO.puts("Terminate with reason #{inspect reason}")
  end

  def code_change(old_vsn, :nada, _extra) do
    IO.puts("Update code from #{old_vsn}")
    {:ok, :nada}
  end

end