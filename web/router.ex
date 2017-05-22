defmodule RollbarExample.Router do
  use RollbarExample.Web, :router
  use Plug.ErrorHandler

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", RollbarExample do
    pipe_through :browser # Use the default browser stack

    get "/", PageController, :index
  end

  # Other scopes may use custom stacks.
  # scope "/api", RollbarExample do
  #   pipe_through :api
  # end

  defp handle_errors(conn, %{kind: kind, reason: reason, stack: stacktrace}) do
    # First, we filter params so we won't send any sensitive data
    conn =
      conn
      |> Plug.Conn.fetch_cookies()
      |> Plug.Conn.fetch_query_params()

    params =
      for {key, _value} = tuple <- conn.params do
        if key in ["password", "password_confirmation"] do
          {key, "[FILTERED]"}
        else
          tuple
        end
      end

    # We make use of Rollbar Item POST API
    # More info about it here: https://rollbar.com/docs/api/items_post/
    conn_data = %{
      "request" => %{
        "cookies" => conn.req_cookies,
        "url" => "#{conn.scheme}://#{conn.host}:#{conn.port}#{conn.request_path}",
        "user_ip" => (conn.remote_ip |> Tuple.to_list() |> Enum.join(".")),
        "headers" => Enum.into(conn.req_headers, %{}),
        "params" => params,
        "method" => conn.method,
      },
      "server" => %{
        "pid" => System.get_env("MY_SERVER_PID"),
        "host" => "#{System.get_env("MY_HOSTNAME")}:#{System.get_env("MY_PORT")}",
        "root" => System.get_env("MY_APPLICATION_PATH"),
      },
    }

    Rollbax.report(kind, reason, stacktrace, %{}, conn_data)
  end
end
