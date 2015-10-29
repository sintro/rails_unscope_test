begin
  require 'bundler/inline'
rescue LoadError => e
  $stderr.puts 'Bundler version 1.10 or later is required. Please update your Bundler'
  raise e
end

gemfile(true) do
  source 'https://rubygems.org'
  gem 'rails', github: 'rails/rails'
  gem 'arel', github: 'rails/arel'
  gem 'rack', github: 'rack/rack'
  gem 'sprockets', github: 'rails/sprockets'
  gem 'sprockets-rails', github: 'rails/sprockets-rails'
  gem 'sass-rails', github: 'rails/sass-rails'
  gem 'sqlite3'
end

require 'active_record'
require 'minitest/autorun'
require 'logger'

# This connection will do for database-independent bug reports.
ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: ':memory:')
ActiveRecord::Base.logger = Logger.new(STDOUT)

ActiveRecord::Schema.define do
  create_table :events, force: true  do |t|
  end

  create_table :nominations, force: true  do |t|
    t.integer :award_id, null: false
    t.integer :event_id, null: false
    t.boolean :approved, null: false, default: false
  end

  create_table :awards, force: true  do |t|
  end
end

class Event < ActiveRecord::Base
  has_many :nominations
  has_many :awards, -> { approved_nomination }, through: :nominations
end

class Nomination < ActiveRecord::Base
  belongs_to :event
  belongs_to :award
end

class Award < ActiveRecord::Base
  has_many :nominations
  has_many :events, through: :nominations

  scope :approved_nomination, -> {where(nominations: {approved: true})}
end

class BugTest < Minitest::Test
  def setup
    Event.destroy_all
    Award.destroy_all
    Nomination.destroy_all

    @event = Event.create!
    @award = Award.create!
    Nomination.create!(event: @event, award: @award, approved: true)
    Nomination.create!(event: @event, award: @award, approved: false)
    Nomination.create!(event: @event, award: @award, approved: false)
  end

  def test_nested_unscope
    # Failed (sad, because this is expected behaviour of this function)
    assert_equal 1, @event.reload.awards.count
    assert_equal 3, @event.reload.awards.unscope(where: {nominations: :approved}).count
  end

  def test_flat_unscope_with_association_name
    # Failed
    assert_equal 1, @event.reload.awards.count
    assert_equal 3, @event.reload.awards.unscope(where: :nominations).count
  end

  def test_flat_unscope_with_last_attribute_name
    # Unexpectedly ok
    assert_equal 1, @event.reload.awards.count
    assert_equal 3, @event.reload.awards.unscope(where: :approved).count
  end

  def test_flat_unscope_with_scope_name
    # Failed
    assert_equal 1, @event.reload.awards.count
    assert_equal 3, @event.reload.awards.unscope(where: :approved_nomination).count
  end

  def test_flat_unscope_with_where
    # Expectedly ok
    assert_equal 1, @event.reload.awards.count
    assert_equal 3, @event.reload.awards.unscope(:where).count
  end
end