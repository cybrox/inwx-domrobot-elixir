# InwxDomrobot
[INWX](https://www.inwx.com/en/) offers a complete JSON-RPC API. The DomRobot API allows you to manage accounts, domains, name servers and much more directly from your application. This package does not wrap all possible commands but instead handles authentication and local session persistence. With this, it provides a simple, consistent interface for executing any query command listed in the [INWX API specification](https://www.inwx.com/en/help/apidoc)

## Installation
Install from [hex.pm](https://hex.pm/packages/inwx_domrobot)

```elixir
def deps do
  [{:inwx_domrobot, "~> 0.1.0"}]
end
```

## Usage
```elixir
# Start a new linked process. Can also be used as supervisor child
# The `endpoint: ` option can be passed for using a custom API endpoint.
iex(1)> {:ok, conn} = InwxDomrobot.start_link([])
{:ok, PID<0.213.0>}

# Send an "account.login" request to the connection
iex(2)> InwxDomrobot.login(conn, "username", "password")
{:ok, 1000}

# Send arbitrary query commands to the connection
iex(3)> InwxDomrobot.query(conn, "account.info")
{:ok, %{"code" => 1000,
  ...
}}

iex(4)> InwxDomrobot.query(conn, "account.update", %{ firstname: "Sven" })
{:ok, %{"code" => 1001,
  ...
}}}

# Send an "account.logout" request to the connection
iex(5)> InwxDomrobot.logout(conn)
{:ok, 1500}
```

### Two-Factor Authentication
This package supports the use of two-factor authentication by providing either the secret or a current TOTP value on login
```elixir
# Using TFA with secret
iex(1)> InwxDomrobot.login(conn, "username", "password", {:secret, "mySecret"})

# Using TFA with current TOTP token
iex(1)> InwxDomrobot.login(conn, "username", "password", {:totp, "000000"})
```

Special thanks to [@jgelens](https://github.com/jgelens) for adding TFA support.
