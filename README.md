# InwxDomrobot
[INWX](https://www.inwx.com/en/) offers a complete XML-RPC API covering most of their sites features. The DomRobot API allows you to manage accounts, domains, name servers and much more directly from your application. Considering the way their API is built, this package merely acts as a cookie storage and an XML encoder/decoder proxy.

Please note that 2FA is currently not supported with this client.


## Installation
Install from [hex.pm](https://hex.pm/)

```elixir
def deps do
  [{:inwx_domrobot, "~> 0.1.0"}]
end
```


## Usage
```elixir
# Send an "account.login" request to the API
iex(1)> InwxDomrobot.login "username", "password"
{:ok, 1000}

# Send arbitrary commands to the API
iex(2)> InwxDomrobot.query "account.info"
{:ok, %XMLRPC.MethodResponse{param: %{"code" => 1000,
  ...
}}}

# Send an "account.logout" request to the API
iex(3)> InwxDomrobot.logout
{:ok,
 %XMLRPC.MethodResponse{param: %{"code" => 1500,
    "msg" => "Command completed successfully; ending session",
    "runtime" => 0.0264, "svTRID" => "..."}}}
```
