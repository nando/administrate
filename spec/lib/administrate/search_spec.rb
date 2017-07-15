require "spec_helper"
require "support/constant_helpers"
require "administrate/field/string"
require "administrate/field/email"
require "administrate/field/number"
require "administrate/search"

# I use the following line to run "rspec spec/lib/administrate/search_spec.rb"
#require File.expand_path("../../../example_app/config/environment", __FILE__)

class MockDashboard
  ATTRIBUTE_TYPES = {
    name: Administrate::Field::String,
    email: Administrate::Field::Email,
    phone: Administrate::Field::Number,
  }
end

class DashboardWithAnArrayOfScopes
  ATTRIBUTE_TYPES = {
    name: Administrate::Field::String,
  }

  COLLECTION_SCOPES = [:active, :old, "with_argument(3)", "idle"]
end

class DashboardWithAHashOfScopes
  ATTRIBUTE_TYPES = {
    name: Administrate::Field::String,
  }

  COLLECTION_SCOPES = {
    status: [:active, :inactive, "idle", "with_argument:*"],
    other: [:last_week, :old, "with_argument(3)",],
  }
end

class DashboardWithScopesDisabled
  ATTRIBUTE_TYPES = {
    name: Administrate::Field::String,
  }

  COLLECTION_SCOPES = []
end

describe Administrate::Search do

  describe "#scopes (and #scope as #scopes.first)" do
    let(:scope) { "active" }

    describe "the query is one scope" do
      let(:query) { "scope:#{scope}" }

      it "returns nil if the model does not respond to the possible scope" do
        begin
          class User < ActiveRecord::Base; end
          scoped_object = User.default_scoped
          search = Administrate::Search.new(scoped_object,
                                            MockDashboard,
                                            nil)
          expect(search.scope).to eq(nil)
        ensure
          remove_constants :User
        end
      end

      it "returns the scope if the model responds to it" do
        begin
          class User < ActiveRecord::Base
            def self.active; end
          end
          scoped_object = User.default_scoped
          search = Administrate::Search.new(scoped_object,
                                            MockDashboard,
                                            query)
          expect(search.scope).to eq(scope)
        ensure
          remove_constants :User
        end
      end

      # DashboardWithScopesDisabled define COLLECTION_SCOPES as an empty array.
      it "returns nil if the dashboard's search into scopes is disabled" do
        begin
          class User < ActiveRecord::Base
            def self.active; end
          end
          scoped_object = User.default_scoped
          search = Administrate::Search.new(scoped_object,
                                            DashboardWithScopesDisabled,
                                            query)
          expect(search.scope).to eq(nil)
        ensure
          remove_constants :User
        end
      end

      it "ignores the case of the 'scope:' prefix" do
        begin
          class User < ActiveRecord::Base
            def self.active; end
          end
          scoped_object = User.default_scoped
          search = Administrate::Search.new(scoped_object,
                                            MockDashboard,
                                            "ScoPE:#{scope}")
          expect(search.scope).to eq(scope)
        ensure
          remove_constants :User
        end
      end

      it "returns nil if the name of the scope looks suspicious" do
        begin
          class User < ActiveRecord::Base
            def self.destroy_all; end
          end
          scoped_object = User.default_scoped
          Administrate::Search::BLACKLISTED_WORDS.each do |word|
            search = Administrate::Search.new(scoped_object,
                                              MockDashboard,
                                              "scope:#{word}_all")
            expect(search.scope).to eq(nil)
          end
        ensure
          remove_constants :User
        end
      end

      it "returns nil if the name of the scope ends with an exclamation mark" do
        begin
          class User < ActiveRecord::Base
            def self.bang!; end
          end

          scoped_object = User.default_scoped
          search = Administrate::Search.new(scoped_object,
                                            MockDashboard,
                                            "scope:bang!")
          expect(search.scope).to eq(nil)
        ensure
          remove_constants :User
        end
      end

      describe "with COLLECTION_SCOPES defined as an array" do
        let(:resolver) do
          double(resource_class: User,
                 dashboard_class: DashboardWithAnArrayOfScopes)
        end

        it "ignores the scope if it isn't included in COLLECTION_SCOPES" do
          begin
            class User < ActiveRecord::Base
              def self.closed; end
            end
            scoped_object = User.default_scoped
            search = Administrate::Search.new(scoped_object,
                                              DashboardWithAnArrayOfScopes,
                                              "scope:closed")
            expect(search.scope).to eq(nil)
          ensure
            remove_constants :User
          end
        end

        it "returns the scope if it's included into COLLECION_SCOPES" do
          begin
            class User < ActiveRecord::Base
              def self.active; end
            end
            scoped_object = User.default_scoped
            search = Administrate::Search.new(scoped_object,
                                              DashboardWithAnArrayOfScopes,
                                              "scope:active")
            expect(search.scope).to eq("active")
          ensure
            remove_constants :User
          end
        end

        # The following should match with what is declared by COLLECTION_SCOPES
        # up within the DashboardWithAnArrayOfScopes class.
        let(:scope) { "with_argument" }
        let(:argument) { "3" }
        let(:scope_with_argument) { "#{scope}(#{argument})" }
        it "returns the scope even if its key has an argument" do
          begin
            class User < ActiveRecord::Base
              def self.with_argument(argument); argument; end
            end
            scoped_object = User.default_scoped
            search = Administrate::Search.new(scoped_object,
                                              DashboardWithAnArrayOfScopes,
                                              "scope:#{scope_with_argument}")
            expect(search.scope).to eq(scope)
            expect(search.scopes).to eq([scope])
            expect(search.arguments).to eq([argument])
          ensure
            remove_constants :User
          end
        end
      end




    end
  end

  describe "#run" do
    it "returns all records when no search term" do
      begin
        class User < ActiveRecord::Base; end
        scoped_object = User.default_scoped
        search = Administrate::Search.new(scoped_object,
                                          MockDashboard,
                                          nil)
        expect(scoped_object).to receive(:all)

        search.run
      ensure
        remove_constants :User
      end
    end

    it "returns all records when search is empty" do
      begin
        class User < ActiveRecord::Base; end
        scoped_object = User.default_scoped
        search = Administrate::Search.new(scoped_object,
                                          MockDashboard,
                                          "   ")
        expect(scoped_object).to receive(:all)

        search.run
      ensure
        remove_constants :User
      end
    end

    it "searches using lower() + LIKE for all searchable fields" do
      begin
        class User < ActiveRecord::Base; end
        scoped_object = User.default_scoped
        search = Administrate::Search.new(scoped_object,
                                          MockDashboard,
                                          "test")
        expected_query = [
          "lower(\"users\".\"name\") LIKE ?"\
          " OR lower(\"users\".\"email\") LIKE ?",
          "%test%",
          "%test%",
        ]
        expect(scoped_object).to receive(:where).with(*expected_query)

        search.run
      ensure
        remove_constants :User
      end
    end

    it "converts search term lower case for latin and cyrillic strings" do
      begin
        class User < ActiveRecord::Base; end
        scoped_object = User.default_scoped
        search = Administrate::Search.new(scoped_object,
                                          MockDashboard,
                                          "Тест Test")
        expected_query = [
          "lower(\"users\".\"name\") LIKE ?"\
          " OR lower(\"users\".\"email\") LIKE ?",
          "%тест test%",
          "%тест test%",
        ]
        expect(scoped_object).to receive(:where).with(*expected_query)

        search.run
      ensure
        remove_constants :User
      end
    end
  end
end
