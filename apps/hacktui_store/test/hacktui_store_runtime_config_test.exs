defmodule HacktuiStore.RuntimeConfigTest do
  use ExUnit.Case, async: true

  alias HacktuiStore.RuntimeConfig

  describe "production_repo_config_errors/2" do
    test "rejects disabled repo in production" do
      repo_config = [
        username: "prod_user",
        password: "super-secret",
        hostname: "postgres.internal",
        port: 5432,
        database: "hacktui_prod"
      ]

      assert ["HACKTUI_START_REPO must be enabled in production"] =
               RuntimeConfig.production_repo_config_errors(false, repo_config)
    end

    test "rejects demo defaults in production" do
      repo_config = [
        username: "hacktui",
        password: "postgres",
        hostname: "localhost",
        port: 5432,
        database: "hacktui_qualification_test"
      ]

      assert RuntimeConfig.production_repo_config_errors(true, repo_config) == [
               "HACKTUI_DB_NAME cannot use the qualification/demo database",
               "HACKTUI_DB_USER cannot use the default demo username",
               "HACKTUI_DB_PASS cannot use the default demo password",
               "HACKTUI_DB_HOST cannot default to localhost in production"
             ]
    end

    test "accepts explicit non-demo production configuration" do
      repo_config = [
        username: "hacktui_app",
        password: "correct-horse-battery-staple",
        hostname: "postgres.service.consul",
        port: 5432,
        database: "hacktui_prod"
      ]

      assert RuntimeConfig.production_repo_config_errors(true, repo_config) == []
    end
  end
end
