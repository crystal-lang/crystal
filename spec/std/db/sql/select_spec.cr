require "spec"
require "db/sql/nodes"
require "db/sql/dialects/mysql"

describe "DB::Sql::Select" do
  it "does to_s for simple query" do
    users = DB::Sql::Table.new(:users)
    query = DB::Sql::Select.from(users).project(users[:name])
    query.to_sql(DB::Sql::MysqlDialect).should eq("SELECT `name` FROM `users`")
  end

  it "does to_s with where" do
    users = DB::Sql::Table.new(:users)
    query = DB::Sql::Select.from(users).project(users[:name]).where(users[:name].eq("John"))
    query.to_sql(DB::Sql::MysqlDialect).should eq("SELECT `name` FROM `users` WHERE `name` = 'John'")
  end
end
