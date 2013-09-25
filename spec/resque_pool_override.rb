Resque::Pool.config_override = ->(config) {
  { "foo" => 1, "bar" => 2, "baz" => 3, "foo,bar,baz" => 4 }
}
