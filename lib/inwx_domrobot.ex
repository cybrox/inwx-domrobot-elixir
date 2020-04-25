defmodule InwxDomrobot do
  use GenServer

  def init(init_arg) do
    {:ok, init_arg}
  end

  @moduledoc """
  An Elixir implementation of the INWX DomRobot.
  INWX offers a complete XML-RPC API covering most of their sites features.
  The DomRobot allows you to manage accounts, domains, name servers and much
  more directly from your application instead of using their webinterface.

  The DomRobot will connect to the XML-RPC API by sending your account information
  to the API via HTTPS. It will store the returned cookie until it is actively logged
  out, in order to allow you to send it the commands you need. This implementation
  uses xmlrpc for building its requests. https://hexdocs.pm/xmlrpc/XMLRPC.html
  """


  @apiurl %{
    dev:  "https://api.ote.domrobot.com/jsonrpc/",
    test: "https://api.ote.domrobot.com/jsonrpc/",
    prod: "https://api.domrobot.com/jsonrpc/"
  }


  @doc """
  Start the INWX Domrobot GenServer process
  Returns typical GenServer response, e.g. `{:ok, connection}`
  """
  def start_link do
    GenServer.start_link(__MODULE__, [""])
  end


  @doc """
  Send an account.login request to the INWX API.
  This method takes a username and password, it is recommended you load those from
  your environment instead of hard-coding them into the application. Upon receiving
  a successful response, the module will hold the received cookie for futher requests.

  There are three possible return tuples for this method.
  If the HTTPoison request failed: `{:error, %HTTPoison.Error}`
  If the successful request returned an error code: `{:error, {:unauthorized, code}}`
  If the successful request returned a success code: `{:ok, code}`
  """
  def login(connection, username, password), do: login(connection, username, password, "")
  def login(connection, username, password, secret) do
    GenServer.call(connection, {:login, username, password, secret})
  end


  @doc """
  Send an account.logout request to the INWX API.
  After receiving a successful response to the logout request, the module will
  discard the current session cookie. InwxDomrobot.login needs to be called again
  with valid credentials afterwards, in order to make any further requests.

  There are two possible return tuples for this method.
  If the HTTPoison request failed: `{:error, %HTTPoison.Error}`
  If the request was successful: `{:ok, %HTTPoison.Response}`
  """
  def logout(connection) do
    GenServer.call(connection, {:logout})
  end


  @doc """
  Send a custom request to the INWX API.
  This method takes a method name and optionally some parameters that will be
  sent to the INWX API. The method name and the respective parameters used can
  be found in the official DomRobot API documentation.

  There are two possible return tuples for this method.
  If the HTTPoison request failed: `{:error, %HTTPoison.Error}`
  If the request was successful: `{:ok, %XMLRPC.MethodResponse}`
  """
  def query(connection, method_name, params \\ []) do
    GenServer.call(connection, {:query, method_name, params})
  end

  def handle_call({:login, username, password, secret}, _from, session) do
    request = %{
      method: "account.login",
      params: %{
          user: username,
          pass: password,
          lang: "en"
      }
    }

    bodydata = Jason.encode!(request)
    HTTPoison.post(api_url(), bodydata)
    |> handle_login(session, secret)
  end

  def handle_call({:logout}, _from, [""]) do
    {:reply, {:ok, "not logged in"}, [""]}
  end

  def handle_call({:logout}, _from, session) do
    request = %{
      method: "account.logout",
      params: []
    }

    bodydata = Jason.encode!(request)
    HTTPoison.post(api_url(), bodydata, [], hackney: [cookie: session])
    |> handle_logout(session)
  end


  def handle_call({:query, method_name, params}, _from, session) do
    request = %{
      method: method_name,
      params: params
    }

    bodydata = Jason.encode!(request)
    HTTPoison.post(api_url(), bodydata, [], hackney: [cookie: session])
    |> handle_query(session)
  end

  defp handle_login({:ok, response}, session, secret) do
    {:ok, decoded} = Jason.decode(response.body)
    code = Map.get(decoded, "code")

    if code == 1000 do
      cookies = Enum.filter(response.headers, fn
        {"Set-Cookie", _} -> true
        _ -> false
      end)

      [{_key, session_value}] = cookies

      if get_in(decoded, ["resData", "tfa"]) != "0" do
        handle_unlock(secret, [session_value])
      else
        {:reply, {:ok, code}, [session_value]}
      end
    else
      {:reply, {:error, {:unauthorized, code}}, session}
    end
  end

  defp handle_login(resp, session, _) do
    {:reply, resp, session}
  end

  defp handle_unlock(secret, session) do
    # TODO check if secret is nil
    otp = Totpex.generate_totp(secret)
    request = %{
      method: "account.unlock",
      params: %{tan: otp}
    }

    bodydata = Jason.encode!(request)
    {:ok, response} = HTTPoison.post(api_url(), bodydata, [], hackney: [cookie: session])
    {:ok, decoded} = Jason.decode(response.body)
    code = Map.get(decoded, "code")

    if code == 1000 do
      {:reply, {:ok, code}, session}
    else
      {:reply, {:error, {:unauthorized, code, Map.get(decoded, "msg")}}, session}
    end
  end

  defp handle_logout({:ok, response}, _session) do
    {:ok, decoded} = Jason.decode(response.body)
    {:reply, {:ok, decoded}, [""]}
  end

  defp handle_logout(resp, session) do
    {:reply, resp, session}
  end

  defp handle_query({:ok, response}, session) do
    {:reply, Jason.decode(response.body), session}
  end

  defp handle_query(resp, session) do
    {:reply, resp, session}
  end

  defp api_url do
    Map.get(@apiurl, Mix.env)
  end
end
