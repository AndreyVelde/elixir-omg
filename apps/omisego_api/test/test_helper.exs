ExUnit.configure(exclude: [integration: true])
Code.require_file("test/testlib/test_helper.ex")
ExUnitFixtures.start()
# need to do this in umbrella apps
ExUnitFixtures.load_fixture_files()
ExUnit.start()
