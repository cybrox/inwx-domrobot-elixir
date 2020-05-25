defmodule InwxDomrobot do
  @moduledoc """
  An Elixir implementation of the INWX DomRobot.

  This library will handle session management and authentication to the INWX API.
  For performing operations using this API wrapper, you will need to follow the
  INWX API specification documented on https://www.inwx.com/en/help/apidoc.
  """

  use GenServer

  defmodule State do
    @type t() :: %__MODULE__{
            endpoint: binary,
            session: binary | nil
          }

    defstruct [:endpoint, :session]
  end

  @env Mix.env()

  @endpoints %{
    dev: "https://api.ote.domrobot.com/jsonrpc/",
    test: "https://api.ote.domrobot.com/jsonrpc/",
    prod: "https://api.domrobot.com/jsonrpc/"
  }

  @default_endpoint Map.get(@endpoints, :dev)

  @type request_error() :: {:error, Mojito.Error.t()}

  @type auth_success() :: {:ok, integer}
  @type auth_error() :: {:error, {:unauthorized, integer} | {:unauthorized, integer, binary}}

  @type unauth_success() :: {:ok, integer}
  @type unauth_error() :: {:error, {integer, binary}}

  @type query_response() :: {:ok, map} | {:error, Jason.DecodeError.t()}

  # ---
  # Server
  # ---

  @spec init(keyword) :: {:ok, __MODULE__.State.t()}
  def init(args) do
    endpoint =
      case Keyword.fetch(args, :endpoint) do
        {:ok, endpoint_uri} -> endpoint_uri
        _ -> Map.get(@endpoints, @env, @default_endpoint)
      end

    {:ok, %__MODULE__.State{endpoint: endpoint}}
  end

  def handle_call({:login, username, password, tfa_info}, _from, state) do
    payload =
      Jason.encode!(%{
        method: "account.login",
        params: %{
          user: username,
          pass: password,
          lang: "en"
        }
      })

    Mojito.post(state.endpoint, [], payload)
    |> handle_login(state, tfa_info)
  end

  def handle_call(:logout, _from, state = %{session: nil}) do
    {:reply, {:ok, :not_logged_in}, state}
  end

  def handle_call(:logout, _from, state) do
    payload =
      Jason.encode!(%{
        method: "account.logout",
        params: []
      })

    Mojito.post(state.endpoint, state.session, payload)
    |> handle_logout(state)
  end

  def handle_call({:query, method_name, params}, _from, state) do
    payload =
      Jason.encode!(%{
        method: method_name,
        params: params
      })

    Mojito.post(state.endpoint, state.session, payload)
    |> handle_query(state)
  end

  defp handle_login({:ok, response}, state, tfa_info) do
    {:ok, decoded} = Jason.decode(response.body)
    tfa_method = get_in(decoded, ["resData", "tfa"]) || "0"
    result_code = Map.get(decoded, "code")

    if result_code == 1000 do
      cookies =
        response.headers
        |> Enum.filter(fn {key, _} -> key == "set-cookie" end)
        |> Enum.at(0, {nil, nil})
        |> elem(1)

      new_state = %{state | session: [{"cookie", cookies}]}

      if tfa_method != "0" do
        handle_unlock(tfa_info, new_state)
      else
        {:reply, {:ok, result_code}, new_state}
      end
    else
      {:reply, {:error, {:unauthorized, result_code}}, state}
    end
  end

  defp handle_login(resp, state, _tfa_info) do
    {:reply, resp, state}
  end

  defp handle_unlock(tfa_info, state) do
    otp =
      case tfa_info do
        {:secret, secret} -> Totpex.generate_totp(secret)
        {:totp, totp} -> totp
        _ -> raise "Invalid tfa information provided!"
      end

    payload =
      Jason.encode!(%{
        method: "account.unlock",
        params: %{tan: otp}
      })

    case Mojito.post(state.endpoint, state.session, payload) do
      {:ok, response} ->
        payload = Jason.decode!(response.body)
        result_code = Map.get(payload, "code")
        result_msg = Map.get(payload, "msg")

        if result_code == 1000 do
          {:reply, {:ok, result_code}, state}
        else
          {:reply, {:error, {:unauthorized, result_code, result_msg}}, state}
        end

      {:error, error} ->
        {:reply, {:error, error}, state}
    end
  end

  defp handle_logout({:ok, response}, state) do
    payload = Jason.decode!(response.body)
    result_code = Map.get(payload, "code")
    result_msg = Map.get(payload, "msg")

    if result_code == 1500 do
      {:reply, {:ok, 1500}, %{state | session: nil}}
    else
      {:reply, {:error, {result_code, result_msg}}, state}
    end
  end

  defp handle_logout(resp, state) do
    {:reply, resp, state}
  end

  defp handle_query({:ok, response}, state) do
    {:reply, Jason.decode(response.body), state}
  end

  defp handle_query(resp, state) do
    {:reply, resp, state}
  end

  # ---
  # Client
  # ---

  @doc """
  Start a linked INWX Domrobot GenServer process.

  By default, the INWX test API will be used in `:dev` and `:test` environment
  and the production INWX API will be used in the `:prod` environment. A custom
  API endpoint to be used can be provided with the `:endpoint` option.
  """
  @spec start_link(keyword) :: {:ok, pid}
  def start_link(args \\ []) do
    GenServer.start_link(__MODULE__, args, [])
  end

  @doc """
  Send an `account.login` request to the INWX API.

  After a successful login, the process will hold the session cookie for future use.
  When two-factor authentication is used, the `tfa_info` must be passed in the format:
  * `{:secret, "my-secret"}` - Providing the secret, the library will generate the TOTP.
  * `{:totp, "000000"}` - Providing a TOTP directly, useful for CLI applications.
  """
  @spec login(pid, binary, binary, {atom, binary} | nil) ::
          auth_success() | auth_error() | request_error()
  def login(conn, username, password, tfa_info \\ nil) do
    GenServer.call(conn, {:login, username, password, tfa_info})
  end

  @doc """
  Send an `account.logout` request to the INWX API.

  After a successful logout, the process will no longer hold the session cookie. The login
  function will need to be used again in order to perform any further query requests.
  """
  @spec logout(pid) :: unauth_success() | unauth_error() | request_error()
  def logout(conn) do
    GenServer.call(conn, :logout)
  end

  @doc """
  Send a custom query to the INWX API.

  This method takes a method name and optionally some parameters that will be
  sent to the INWX API. The method name and the respective parameters used can
  be found in the official INWX API documentation.
  """
  @spec query(pid, binary, map) :: query_response() | request_error()
  def query(conn, method_name, params \\ %{}) do
    GenServer.call(conn, {:query, method_name, params})
  end
end
