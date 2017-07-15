require "active_support/core_ext/module/delegation"
require "active_support/core_ext/object/blank"

module Administrate
  class Search
    # Only used if dashboard's COLLECTION_SCOPES is not defined
    BLACKLISTED_WORDS = %w{destroy remove delete update create}.freeze

    def initialize(scoped_resource, dashboard_class, term)
      @dashboard_class = dashboard_class
      @scoped_resource = scoped_resource
      @term = term
      @words, @scopes = words_and_scopes_of(@term.present? ? @term.split : [])
    end

    def scopes
      @scopes.map(&:name)
    end

    def arguments
      @scopes.map(&:argument)
    end

    def scopes_with_arguments
      @scopes.map(&:user_input)
    end

    def scope
      scopes.first
    end

    def run
      if @term.blank?
        @scoped_resource.all
      else
        @scoped_resource.where(query, *search_terms)
      end
    end

    private

    def query
      search_attributes.map do |attr|
        table_name = ActiveRecord::Base.connection.
          quote_table_name(@scoped_resource.table_name)
        attr_name = ActiveRecord::Base.connection.quote_column_name(attr)
        "lower(#{table_name}.#{attr_name}) LIKE ?"
      end.join(" OR ")
    end

    def search_terms
      ["%#{term.mb_chars.downcase}%"] * search_attributes.count
    end

    def search_attributes
      attribute_types.keys.select do |attribute|
        attribute_types[attribute].searchable?
      end
    end

    def attribute_types
      @dashboard_class::ATTRIBUTE_TYPES
    end

    # Extracts the possible scope from *term* (a single word string) and
    # returns it if the model responds to it and is a valid_scope?
    def scope_object(term)
      if term && (/(?<left_part>\w+):(?<right_part>.+)/i =~ term)
        obj = build_scope_ostruct(left_part, right_part)
        obj if @scoped_resource.respond_to?(obj.name) && valid_scope?(obj)
      end
    end

    def build_scope_ostruct(left_part, right_part)
      if left_part.casecmp("scope") == 0
        user_input = right_part
        if /(?<scope_name>\w+)\((?<scope_argument>\w+)\)/ =~ right_part
          name = scope_name
          argument = scope_argument
        else
          name = user_input
          argument = nil
        end
      else
        user_input = "#{left_part}:#{right_part}"
        name = left_part
        argument = right_part
      end
      OpenStruct.new(user_input: user_input, name: name, argument: argument)
    end

    # If the COLLECTION_SCOPES is not empty returns true if the possible_scope
    # is included in it (i.e. whitelisted), and returns false if is empty.
    # If COLLECTION_SCOPES isn't defined returns true if it's not blacklisted
    # nor ending with an exclamation mark.
    def valid_scope?(scope_obj)
      if collection_scopes.any?
        collection_scopes_include?(scope_obj.user_input) ||
          wildcarded_scope?(scope_obj.name)
      elsif @dashboard_class.const_defined?(:COLLECTION_SCOPES)
        false
      else
        !banged?(scope_obj.user_input) &&
          !blacklisted_scope?(scope_obj.user_input)
      end
    end

    def collection_scopes_include?(s)
      collection_scopes.include?(s) || collection_scopes.include?(s.to_sym)
    end

    def wildcarded_scope?(scope)
      collection_scopes.include?("#{scope}:*")
    end

    def banged?(method)
      method[-1, 1] == "!"
    end

    def blacklisted_scope?(scope)
      BLACKLISTED_WORDS.each do |word|
        return true if scope =~ /.*#{word}.*/i
      end
      false
    end

    def collection_scopes
      @_scopes ||= if @dashboard_class.const_defined?(:COLLECTION_SCOPES)
                     const = @dashboard_class.const_get(:COLLECTION_SCOPES)
                     const.is_a?(Array) ? const : const.values.flatten
                   else
                     []
                   end
    end

    # Recursive function that takes a splited search string (term) as input and
    # returns an array with two arrays: the first with the ordinary words and
    # the other with the scopes.
    def words_and_scopes_of(terms, words = [], scopes = [])
      if terms.any?
        first_term = terms.shift
        if scope_obj = scope_object(first_term)
          words_and_scopes_of terms, words, scopes.push(scope_obj)
        else
          words_and_scopes_of terms, words.push(first_term), scopes
        end
      else
        [words, scopes]
      end
    end




    attr_reader :resolver, :term, :words
  end
end
