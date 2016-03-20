defmodule CoAP.Server.State do

 defstruct udp: nil, inner_state: nil, module: :none

end

defmodule CoAP.Server do
  use CoAP.Codes

  @defaults [
    port: @coap_port]

  defmacro __using__(_) do
    quote do
      @behaviour unquote(__MODULE__)

      def init(args) do
        {:ok, args}
      end

      def handle_invalid(_error, _from, state) do
        {:noreply, state}
      end

      def handle_info(_info, state) do
        {:noreply, state}
      end

      def terminate(_reason, _state) do
        :ok
      end

      def code_change(_old_vsn, state, _extra) do
        {:ok, state}
      end

      defoverridable [
        init: 1,
        handle_invalid: 3,
        handle_info: 2,
        terminate: 2,
        code_change: 3]

    end
  end

  @type on_start :: {:ok, pid} | :ignore | {:error, {:already_started, pid} | term}

  @type sender :: {:inet.ip_address | :inet.hostname, :inet.port_number}

  @type async_fun :: ((:start | term) -> :end | {CoAP.Message.t, term})

  @callback init(args :: term) ::
    {:ok, state} |
    {:ok, state, timeout | :hibernate} |
    :ignore |
    {:stop, reason :: any} when state: any

  @callback handle_confirmable(message :: CoAP.Message.t, from :: sender, state :: term) ::
    {:reply, reply, new_state} |
    {:reply, reply, new_state, timeout | :hibernate} |
    {:reply_async, async_fun, new_state} |
    {:reply_async, async_fun, new_state, timeout | :hibernate} |
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

  @spec start_link(module :: atom, args :: any, opts :: [atom: term]) :: on_start
  def start_link(module, args, opts \\ []) do
    opts = Keyword.merge(@defaults, is_list(opts) && opts || [])
    GenServer.start_link(CoAP.Server.Adapter, {module, args, opts})
  end

end

defmodule CoAP.Server.Adapter do
  use GenServer

  alias CoAP.{Message, Parser, Serializer}
  alias CoAP.Server.State

  def init({module, inner_args, opts}) do
    case UDP.start_link(port: opts[:port], handlers: []) do
      {:ok, udp} ->
        UDP.listen(udp)
        state = %State{udp: udp, module: module}
        inner_init(state, inner_args)
      error ->
        error
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

  def handle_cast({:message, from, msg}, state) do
    case CoAP.type(msg) do
      :confirmable ->
        inner_call state, msg, from, &(&1.handle_confirmable(msg, from, &2))
      _ ->
        inner_cast state, &(&1.handle_other(msg, from, &2))
    end
  end

  def handle_cast({:invalid, from, error}, state) do
    inner_cast state, &(&1.handle_invalid(error, from, &2))
  end

  def handle_info({:datagram, {_udp, address, port, data}}, state) do
    from = {address, port}
    try do
      msg = Parser.parse(data)
      GenServer.cast(self, {:message, from, msg})
    rescue
      e -> GenServer.cast(self, {:invalid, from, e})
    end
    {:noreply, state}
  end

  def handle_info(info, state) do
    inner_cast state, &(&1.handle_info(info, &2))
  end

  defp inner_call(state, msg, from, action) do
    #TODO copy token from original msg, if missing
    case action.(state.module, state.inner_state) do
      {:reply, reply, new_inner_state} ->
        udp_send(state.udp, from, reply)
        {:noreply, update_state(state, new_inner_state)}
      {:reply, reply, new_inner_state, timeout} ->
        udp_send(state.udp, from, reply)
        {:noreply, update_state(state, new_inner_state), timeout}
      {:reply_async, fun, new_inner_state} ->
        handle_async(state.udp, from, fun)
        {:noreply, update_state(state, new_inner_state)}
      {:reply_async, fun, new_inner_state, timeout} ->
        handle_async(state.udp, from, fun)
        {:noreply, update_state(state, new_inner_state), timeout}
      {:noreply, new_inner_state} ->
        udp_send(state.udp, from, Message.ack(msg))
        {:noreply, update_state(state, new_inner_state)}
      {:noreply, new_inner_state, timeout} ->
        udp_send(state.udp, from, Message.ack(msg))
        {:noreply, update_state(state, new_inner_state), timeout}
      {:stop, reason, reply, new_inner_state} ->
        udp_send(state.udp, from, Message.ack(msg))
        {:stop, reason, reply, new_inner_state}
      {:stop, reason, new_inner_state} ->
        udp_send(state.udp, from, Message.ack(msg))
        {:stop, reason, update_state(state, new_inner_state)}
    end
  end

  defp handle_async(udp, from, fun) do
    {:ok, _pid} = GenServer.start_link(
      CoAP.Server.Async, {fun, &udp_send(udp, from, &1)})
  end

  defp inner_cast(state, action) do
    case action.(state.module, state.inner_state) do
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

  defp udp_send(udp, {from_addr, from_port}, response) do
    try do
      data = Serializer.serialize(response)
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

defmodule CoAP.Server.Async do
  use GenServer

  @inital_state :start

  @final_state :end

  def init({fun, send}) do
    continue
    {:ok, {fun, send, @inital_state}}
  end

  def handle_cast(:continue, {fun, send, state}) do
    case run_safe(fun, state) do
      @final_state ->
        {:stop, :normal, @final_state}
      {msg, new_state} ->
        send.(msg)
        continue
        {:noreply, {fun, send, new_state}}
      _ ->
        {:stop, :normal, @final_state}
    end
  end

  defp run_safe(fun, state) do
    try do
      fun.(state)
    rescue
      _ -> @final_state
    end
  end

  defp continue do
    GenServer.cast(self, :continue)
  end

end
