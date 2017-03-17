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


  def start_link do
    {:ok, _pid} = GenServer.start_link(__MODULE__, [], name: :inwxdomrobot)
  end

  def login(username, password) do
    GenServer.call(:inwxdomrobot, {:login, username, password,})
  end

  def logout do
    GenServer.call(:inwxdomrobot, {:logout})
  end

  def query(query) do
    GenServer.call(:inwxdomrobot, {:query, query})
  end


  def handle_call({:login, username, password}, _from, _session) do
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
    |> handle_login
  end


  defp handle_login({:ok, response}) do
    {:ok, decoded} = XMLRPC.decode(response.body)
    code = Map.get(decoded.param, "code")

    if code == 1000 do
      cookies = Enum.filter(response.headers, fn
        {"Set-Cookie", _} -> true
        _ -> false
      end)

      {:reply, {:ok, code}, cookies}
    else
      {:reply, {:error, code}, []}
    end
  end

  defp handle_login(resp = {:error, response}) do
    {:reply, resp, []}
  end

  defp api_url do
    Map.get(@apiurl, Mix.env)
  end
end
