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
      with_mock(Mojito, [], post: fn _, _, _ -> {:error, :aborted} end) do
        {:ok, conn} = InwxDomrobot.start_link(endpoint: @dummy_endpoint)
        {:error, :aborted} = InwxDomrobot.login(conn, "username", "password")

        assert_called(
          Mojito.post(
            @dummy_endpoint,
            [],
            Jason.encode!(%{
              method: "account.login",
              params: %{
                lang: "en",
                user: "username",
                pass: "password"
              }
            })
          )
        )
      end
    end

    test "returns ok and stores session when login without tfa was successful" do
      dummy_response = %Mojito.Response{
        headers: [{"set-cookie", "domrobot=sessioncookie; path=/"}],
        body: Jason.encode!(%{code: 1000})
      }

      with_mock(Mojito, [], post: fn _, _, _ -> {:ok, dummy_response} end) do
        {:ok, conn} = InwxDomrobot.start_link(endpoint: @dummy_endpoint)
        assert InwxDomrobot.login(conn, "username", "password") == {:ok, 1000}
        assert :sys.get_state(conn).session == [{"cookies", "domrobot=sessioncookie; path=/"}]
      end
    end

    test "returns ok and stores session when login with tfa was successful" do
      dummy_response_one = %Mojito.Response{
        headers: [{"set-cookie", "domrobot=sessioncookie; path=/"}],
        body: Jason.encode!(%{code: 1000, resData: %{tfa: "GOOGLE_AUTHENTICATOR"}})
      }

      dummy_response_two = %Mojito.Response{
        body: Jason.encode!(%{code: 1000})
      }

      with_mock(Mojito, [],
        post: fn _, _, body ->
          case body |> Jason.decode!() |> Map.get("method") do
            "account.login" -> {:ok, dummy_response_one}
            "account.unlock" -> {:ok, dummy_response_two}
          end
        end
      ) do
        {:ok, conn} = InwxDomrobot.start_link(endpoint: @dummy_endpoint)
        assert InwxDomrobot.login(conn, "username", "password") == {:ok, 1000}
        assert :sys.get_state(conn).session == [{"cookies", "domrobot=sessioncookie; path=/"}]
      end
    end

    test "returns raw error when mojito returned an error on login" do
      with_mock(Mojito, [], post: fn _, _, _ -> {:error, %Mojito.Error{}} end) do
        {:ok, conn} = InwxDomrobot.start_link(endpoint: @dummy_endpoint)
        assert InwxDomrobot.login(conn, "username", "password") == {:error, %Mojito.Error{}}
      end
    end

    test "returns error when a non-1000 result code was returned on login" do
      dummy_response = %Mojito.Response{body: Jason.encode!(%{code: 2002})}

      with_mock(Mojito, [], post: fn _, _, _ -> {:ok, dummy_response} end) do
        {:ok, conn} = InwxDomrobot.start_link(endpoint: @dummy_endpoint)
        assert InwxDomrobot.login(conn, "username", "password") == {:error, {:unauthorized, 2002}}
      end
    end

    test "returns raw error when mojitor returned an error on unlock" do
      dummy_response_one = %Mojito.Response{body: Jason.encode!(%{code: 1000})}

      with_mock(Mojito, [],
        post: fn _, _, body ->
          case body |> Jason.decode!() |> Map.get("method") do
            "account.login" -> {:ok, dummy_response_one}
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
      dummy_response_one = %Mojito.Response{body: Jason.encode!(%{code: 1000})}
      dummy_response_two = %Mojito.Response{body: Jason.encode!(%{code: 2002, msg: "failed!"})}

      with_mock(Mojito, [],
        post: fn _, _, body ->
          case body |> Jason.decode!() |> Map.get("method") do
            "account.login" -> {:ok, dummy_response_one}
            "account.unlock" -> {:ok, dummy_response_two}
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
