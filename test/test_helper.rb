ENV["RAILS_ENV"] = "test"

require_relative "./simple_cov"
require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_help'

require 'factory_girl'
require 'mocha/setup'

require_relative '../lib/measures/baseline_loader.rb'

FactoryGirl.find_definitions

class ActiveSupport::TestCase

  def dump_database
    User.delete_all
    Provider.delete_all
    Record.delete_all
    db = Mongoid.default_client
    db['measures'].drop()
    db['selected_measures'].drop()
    db['records'].drop
    db['patient_cache'].drop
    db['query_cache'].drop
    db['bundles'].drop
  end

  def load_code_sets
    MONGO_DB['races'].drop() if MONGO_DB['races']
    MONGO_DB['ethnicities'].drop() if MONGO_DB['ethnicities']
    JSON.parse(File.read(File.join(Rails.root, 'test', 'fixtures', 'code_sets', 'races.json'))).each do |document|
      MONGO_DB['races'].insert_one(document)
    end
    JSON.parse(File.read(File.join(Rails.root, 'test', 'fixtures', 'code_sets', 'ethnicities.json'))).each do |document|
      MONGO_DB['ethnicities'].insert_one(document)
    end
  end

  def load_measure_baselines
    # Drop all measure baselines and reload
    Measures::BaselineLoader.import_json File.join(Rails.root, 'test', 'fixtures', 'measure_baselines.json'), true
  end

  def raw_post(action, body, parameters = nil, session = nil, flash = nil)
    @request.env['RAW_POST_DATA'] = body
    post(action, parameters, session, flash)
  end

  def basic_signin(user)
     @request.env['HTTP_AUTHORIZATION'] = "Basic #{ActiveSupport::Base64.encode64("#{user.username}:#{user.password}")}"
  end

  def collection_fixtures(*collection_names)
    collection_names.each do |collection|
      MONGO_DB[collection].drop
      Dir.glob(File.join(Rails.root, 'test', 'fixtures', collection, '*.json')).each do |json_fixture_file|
        fixture_json = JSON.parse(File.read(json_fixture_file))
        set_mongoid_ids(fixture_json)
        if fixture_json.kind_of?(Array)
          MONGO_DB[collection].insert_many(fixture_json)
        else
          MONGO_DB[collection].insert_one(fixture_json)
        end
      end
    end
  end

  def set_mongoid_ids(json)
    if json.kind_of?( Hash)
      json.each_pair do |k,v|
        if (v && v.kind_of?(Array))
          json[k].each {|item| set_mongoid_ids(item)}
        elsif v && v.kind_of?( Hash )
          if v["$oid"]
            json[k] = BSON::ObjectId.from_string(v["$oid"])
          else
            set_mongoid_ids(v)
          end
        end
      end
    end
  end

  def hash_includes?(expected, actual)
    if (actual.is_a? Hash)
      (expected.keys & actual.keys).all? {|k| expected[k] == actual[k]}
    elsif (actual.is_a? Array )
      actual.any? {|value| hash_includes? expected, value}
    else
      false
    end
  end

  def assert_false(value)
    assert !value
  end

  def assert_query_results_equal(factory_result, result)

    factory_result.each do |key, value|
      assert_equal value, result[key] unless key == '_id'
    end

  end

end
