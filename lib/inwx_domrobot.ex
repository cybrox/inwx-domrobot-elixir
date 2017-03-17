defmodule InwxDomrobot do
  use GenServer

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
    dev:  "https://api.ote.domrobot.com/xmlrpc/",
    test: "https://api.ote.domrobot.com/xmlrpc/",
    prod: "https://api.domrobot.com/xmlrpc/"
  }


  @doc """
  Start the INWX Domrobot GenServer process
  Returns nothing, since all message passing is abstracted internally.
  """
  def start_link do
    {:ok, _pid} = GenServer.start_link(__MODULE__, [{"domrobot", "none"}], name: :inwxdomrobot)
  end


  @doc """
  Send an account.login request to the INWX API.
  This method takes a username and password, it is recommended you load those from
  your environment instead of hard-coding them into the application. Upon receiving
  a successful response, the module will hold the received cookie for futher requests.

  There are three possible return tuples for this method.
  If the HTTPoison request failed: `{:error, %HTTPoison.Error}`
  If the successful request returned an error code: `{:unauthorized, code}`
  If the successful request returned a success code: `{:ok, code}`
  """
  def login(username, password) do
    GenServer.call(:inwxdomrobot, {:login, username, password,})
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
  def logout do
    GenServer.call(:inwxdomrobot, {:logout})
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
  def query(method_name, params \\ []) do
    GenServer.call(:inwxdomrobot, {:query, method_name, params})
  end




  def handle_call({:login, username, password}, _from, session) do
    request = %XMLRPC.MethodCall{
      method_name: "account.login",
      params: [
        %{
          user: username,
          pass: password,
          lang: "en"
        }
      ]
    }

    bodydata = XMLRPC.encode!(request)
    HTTPoison.post(api_url(), bodydata)
    |> handle_login(session)
  end


  def handle_call({:logout}, _from, session) do
    request = %XMLRPC.MethodCall{
      method_name: "account.logout"
    }

    bodydata = XMLRPC.encode!(request)
    HTTPoison.post(api_url(), bodydata, hackney: [cookie: session])
    |> handle_logout(session)
  end


  def handle_call({:query, method_name, params}, _from, session) do
    request = %XMLRPC.MethodCall{
      method_name: method_name,
      params: params
    }

    bodydata = XMLRPC.encode!(request)
    HTTPoison.post(api_url(), bodydata, [], hackney: [cookie: session])
    |> handle_query(session)
  end




  defp handle_login({:ok, response}, session) do
    {:ok, decoded} = XMLRPC.decode(response.body)
    code = Map.get(decoded.param, "code")

    if code == 1000 do
      cookies = Enum.filter(response.headers, fn
        {"Set-Cookie", _} -> true
        _ -> false
      end)

      [{_key, value}] = cookies
      {:reply, {:ok, code}, [value]}
    else
      {:reply, {:unauthorized, code}, session}
    end
  end

  defp handle_login(resp, session) do
    {:reply, resp, session}
  end


  defp handle_logout(resp = {:ok, _response}, _session) do
    {:reply, resp, [""]}
  end

  defp handle_logout(resp, session) do
    {:reply, resp, session}
  end


  defp handle_query({:ok, response}, session) do
    {:reply, XMLRPC.decode(response.body), session}
  end

  defp handle_query(resp, session) do
    {:reply, resp, session}
  end


  defp api_url do
    Map.get(@apiurl, Mix.env)
  end
end
