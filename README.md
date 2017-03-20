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
InwxDomrobot.login "username", "password"

# Send arbitrary commands to the API
InwxDomrobot.query "account.info"
InwxDomrobot.query "acocunt.update", [
  %{
    username: "example",
  }
]

# Send an "account.logout" request to the API
iex(4)> InwxDomrobot.logout
```
