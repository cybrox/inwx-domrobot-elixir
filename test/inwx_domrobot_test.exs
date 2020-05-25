defmodule InwxDomrobotTest do
  use ExUnit.Case
  import Mock

  @dummy_endpoint "https://someendpoint.com"
  @default_endpoint "https://api.ote.domrobot.com/jsonrpc/"

  describe "start_link/1" do
    test "accepts custom endpoint configuration" do
      {:ok, pid} = InwxDomrobot.start_link(endpoint: @dummy_endpoint)
      assert :sys.get_state(pid) == %InwxDomrobot.State{endpoint: @dummy_endpoint, session: nil}
    end

    test "uses inwx development endpoint in test env perdefault" do
      {:ok, pid} = InwxDomrobot.start_link()
      assert :sys.get_state(pid) == %InwxDomrobot.State{endpoint: @default_endpoint, session: nil}
    end
  end

  describe "login/3" do
    test "sends properly formatted login request" do
      exp_login_payload = Jason.encode!(%{
        method: "account.login",
        params: %{
          lang: "en",
          user: "username",
          pass: "password"
        }
      })

      with_mock(Mojito, [], post: fn _, _, _ -> {:error, :aborted} end) do
        {:ok, conn} = InwxDomrobot.start_link(endpoint: @dummy_endpoint)
        {:error, :aborted} = InwxDomrobot.login(conn, "username", "password")
        assert_called(Mojito.post(@dummy_endpoint, [], exp_login_payload))
      end
    end

    test "sends properly formatted unlock request" do
      dummy_login_response = %Mojito.Response{
        headers: [{"set-cookie", "domrobot=sessioncookie; path=/"}],
        body: Jason.encode!(%{code: 1000, resData: %{tfa: "GOOGLE_AUTHENTICATOR"}})
      }

      exp_login_payload =
        Jason.encode!(%{
          method: "account.login",
          params: %{
            lang: "en",
            user: "username",
            pass: "password"
          }
        })

      exp_unlock_header = [
        {"cookie", "domrobot=sessioncookie; path=/"}
      ]

      exp_unlock_payload_one =
        Jason.encode!(%{
          method: "account.unlock",
          params: %{
            tan: "202020"
          }
        })

      exp_unlock_payload_two =
        Jason.encode!(%{
          method: "account.unlock",
          params: %{
            tan: Totpex.generate_totp("mySecret")
          }
        })

      with_mock(Mojito, [], post: fn _, _, _ -> {:ok, dummy_login_response} end) do
        {:ok, conn} = InwxDomrobot.start_link(endpoint: @dummy_endpoint)
        {:ok, 1000} = InwxDomrobot.login(conn, "username", "password", {:totp, "202020"})

        assert_called(Mojito.post(@dummy_endpoint, [], exp_login_payload))
        assert_called(Mojito.post(@dummy_endpoint, exp_unlock_header, exp_unlock_payload_one))
      end

      with_mock(Mojito, [], post: fn _, _, _ -> {:ok, dummy_login_response} end) do
        {:ok, conn} = InwxDomrobot.start_link(endpoint: @dummy_endpoint)
        {:ok, 1000} = InwxDomrobot.login(conn, "username", "password", {:secret, "mySecret"})

        assert_called(Mojito.post(@dummy_endpoint, [], exp_login_payload))
        assert_called(Mojito.post(@dummy_endpoint, exp_unlock_header, exp_unlock_payload_two))
      end
    end

    test "returns ok and stores session when login without tfa was successful" do
      dummy_login_response = %Mojito.Response{
        headers: [{"set-cookie", "domrobot=sessioncookie; path=/"}],
        body: Jason.encode!(%{code: 1000})
      }

      with_mock(Mojito, [], post: fn _, _, _ -> {:ok, dummy_login_response} end) do
        {:ok, conn} = InwxDomrobot.start_link(endpoint: @dummy_endpoint)
        assert InwxDomrobot.login(conn, "username", "password") == {:ok, 1000}
        assert :sys.get_state(conn).session == [{"cookie", "domrobot=sessioncookie; path=/"}]
      end
    end

    test "returns ok and stores session when login with tfa was successful" do
      dummy_login_response = %Mojito.Response{
        headers: [{"set-cookie", "domrobot=sessioncookie; path=/"}],
        body: Jason.encode!(%{code: 1000, resData: %{tfa: "GOOGLE_AUTHENTICATOR"}})
      }

      dummy_unlock_response = %Mojito.Response{
        body: Jason.encode!(%{code: 1000})
      }

      with_mock(Mojito, [],
        post: fn _, _, body ->
          case body |> Jason.decode!() |> Map.get("method") do
            "account.login" -> {:ok, dummy_login_response}
            "account.unlock" -> {:ok, dummy_unlock_response}
          end
        end
      ) do
        {:ok, conn} = InwxDomrobot.start_link(endpoint: @dummy_endpoint)
        assert InwxDomrobot.login(conn, "username", "password") == {:ok, 1000}
        assert :sys.get_state(conn).session == [{"cookie", "domrobot=sessioncookie; path=/"}]
      end
    end

    test "returns raw error when Mojito returned an error on login" do
      with_mock(Mojito, [], post: fn _, _, _ -> {:error, %Mojito.Error{}} end) do
        {:ok, conn} = InwxDomrobot.start_link(endpoint: @dummy_endpoint)
        assert InwxDomrobot.login(conn, "username", "password") == {:error, %Mojito.Error{}}
      end
    end

    test "returns error when a non-1000 result code was returned on login" do
      dummy_login_response = %Mojito.Response{body: Jason.encode!(%{code: 2002})}

      with_mock(Mojito, [], post: fn _, _, _ -> {:ok, dummy_login_response} end) do
        {:ok, conn} = InwxDomrobot.start_link(endpoint: @dummy_endpoint)
        assert InwxDomrobot.login(conn, "username", "password") == {:error, {:unauthorized, 2002}}
      end
    end

    test "returns raw error when Mojito returned an error on unlock" do
      dummy_login_response = %Mojito.Response{body: Jason.encode!(%{
        code: 1000,
        resData: %{tfa: "GOOGLE_AUTHENTICATOR"}
      })}

      with_mock(Mojito, [],
        post: fn _, _, body ->
          case body |> Jason.decode!() |> Map.get("method") do
            "account.login" -> {:ok, dummy_login_response}
            "account.unlock" -> {:error, %Mojito.Error{}}
          end
        end
      ) do
        {:ok, conn} = InwxDomrobot.start_link(endpoint: @dummy_endpoint)

        assert InwxDomrobot.login(conn, "username", "password", {:totp, "202020"}) ==
                 {:error, %Mojito.Error{}}
      end
    end

    test "returns error when a non-1000 result was returned on unlock" do
      dummy_login_response = %Mojito.Response{body: Jason.encode!(%{
        code: 1000,
        resData: %{tfa: "GOOGLE_AUTHENTICATOR"}
      })}

      dummy_unlock_response = %Mojito.Response{body: Jason.encode!(%{code: 2002, msg: "failed!"})}

      with_mock(Mojito, [],
        post: fn _, _, body ->
          case body |> Jason.decode!() |> Map.get("method") do
            "account.login" -> {:ok, dummy_login_response}
            "account.unlock" -> {:ok, dummy_unlock_response}
          end
        end
      ) do
        {:ok, conn} = InwxDomrobot.start_link(endpoint: @dummy_endpoint)

        assert InwxDomrobot.login(conn, "username", "password", {:totp, "202020"}) ==
                 {:error, {:unauthorized, 2002, "failed!"}}
      end
    end
  end
end
