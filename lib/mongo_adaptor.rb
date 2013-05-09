require 'mongo'
require 'mongo-configure'
require "mongo_adaptor/version"

class MongoAdaptor
  class << self
    def db
      @db ||= Mongo::Configure.current.load
    end
  end

  def initialize name, klass
    @collection = self.class.db.collection name.to_s.downcase
    @klass = klass
  end

  def insert model
    @collection.insert process(model), safe_mode
  end

  def upsert model, query = { "_id" => model.id }
    @collection.update query, set(process(model)), safe_mode.merge(upsert_mode true)
  end

  def update model, query = { "_id" => model.id }
    @collection.update query, set(process(model)), safe_mode.merge(upsert_mode false)
  end

  def execute query_or_model, command, options = {}
    if query_or_model.is_a? Hash
      query = query_or_model
    else
      query = { "_id" => query_or_model.id }
    end
    @collection.update query, command, safe_mode.merge(upsert_mode false).merge(options)
  end

  def fetch selector = {}, opts = { :fields => fields }
    @collection.find_one selector, opts.merge( :transformer => builder )
  end

  def remove selector = {}, opts = {}
    @collection.remove selector, opts
  end

  def find selector = {}, opts = { :fields => fields }
    @collection.find selector, opts.merge( :transformer => builder )
  end

  private

    def builder
      proc do |result|
        @klass.new.tap do |model|
          model[:id] = result.delete('_id') if model.respond_to?(:id)
          result.each do |field,value|
            model[field] = value if fields.include?(field.to_s)
          end
        end
      end
    end

    def fields
      @fields ||= @klass.members.map(&:to_s) if @klass
    end

    def process(model)
      fields = {}
      model.each_pair { |field,value| fields[field] = value unless field == :id }
      fields
    end

    def safe_mode
      { :w => 1 }
    end

    def upsert_mode level
      { :upsert => level }
    end

    def set query
      { "$set" => query }
    end

end
