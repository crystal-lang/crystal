# The DB module is a unified interface to database access.
# Database dialects is supported by custom database driver shards.
# Check [manastech/crystal-sqlite3](https://github.com/manastech/crystal-sqlite3) for example.
#
# Drivers implementors check `Driver` class.
#
# Currently a *single connection* to the database is stablished.
# In the future a connection pool and transaction support will be available.
#
# ### Usage
#
# Assuming `crystal-sqlite3` is included a sqlite3 database can be opened with `#open`.
#
# ```
# db = DB.open "sqlite3", ":memory:" # or the sqlite3 file path
# db.close
# ```
#
# If a block is given to `#open` the database is closed automatically
#
# ```
# DB.open "sqlite3", ":memory:" do |db|
#   # work with db
# end # db is closed
# ```
#
# Three kind of statements can be performed:
# 1. `Database#exec` waits no response from the database.
# 2. `Database#scalar` reads a single value of the response.
# 3. `Database#query` returns a ResultSet that allows iteration over the rows in the response and column information.
#
# All of the above methods allows parametrised query. Either positional or named arguments.
#
# Check a full working version:
#
# ```
# require "db"
# require "sqlite3"
#
# DB.open "sqlite3", ":memory:" do |db|
#   db.exec "create table contacts (name string, age integer)"
#   db.exec "insert into contacts values (?, ?)", "John Doe", 30
#   db.exec "insert into contacts values (:name, :age)", {name: "Sarah", age: 33}
#
#   puts "max age:"
#   puts db.scalar "select max(age) from contacts" # => 33
#
#   puts "contacts:"
#   db.query "select name, age from contacts order by age desc" do |rs|
#     puts "#{rs.column_name(0)} (#{rs.column_name(1)})"
#     # => name (age)
#     rs.each do
#       puts "#{rs.read(String)} (#{rs.read(Int32)})"
#       # => Sarah (33)
#       # => John Doe (30)
#     end
#   end
# end
# ```
#
module DB
  # Types supported to interface with database driver.
  # These can be used in any `ResultSet#read` or any `Database#query` related
  # method to be used as query parameters
  TYPES = [String, Int32, Int64, Float32, Float64, Slice(UInt8)]

  # See `DB::TYPES` in `DB`. `Any` is a nillable version of the union of all types in `DB::TYPES`
  alias Any = Nil | String | Int32 | Int64 | Float32 | Float64 | Slice(UInt8)

  # Result of a `#exec` statement.
  record ExecResult, rows_affected, last_insert_id

  # :nodoc:
  def self.driver_class(driver_name) # : Driver.class
    @@drivers.not_nil![driver_name]
  end

  # Registers a driver class for a given `driver_name`.
  # Should be called by drivers implementors only.
  def self.register_driver(driver_name, driver_class : Driver.class)
    @@drivers ||= {} of String => Driver.class
    @@drivers.not_nil![driver_name] = driver_class
  end

  # Opens a database using the `driver_name` registered driver.
  # Uses `connection_string` for connection configuration.
  # Returned database must be closed by `Database#close`.
  def self.open(driver_name, connection_string)
    Database.new(driver_class(driver_name), connection_string)
  end

  # Same as `#open` but the database is yielded and closed automatically.
  def self.open(driver_name, connection_string, &block)
    open(driver_name, connection_string).tap do |db|
      yield db
      db.close
    end
  end
end

require "./query_methods"
require "./disposable"
require "./database"
require "./driver"
require "./connection"
require "./statement"
require "./result_set"
