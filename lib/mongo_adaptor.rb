require 'mongo'
require 'mongo-configure'
require "mongo_adaptor/version"

class MongoAdaptor
  class << self
    def db
      @db ||= Mongo::Configure.current.load
    end
  end

  def initialize(name,klass)
    @collection = self.class.db.collection name.to_s.downcase
    @klass = klass
  end

  def insert(model)
    @collection.insert( process(model), { :safe => true } )
  end
  def update(model)
    @collection.update( { "_id" => model.id }, { "$set" => process(model) }, { :safe => true, :upsert => false } )
  end

  def fetch(*args)
    @collection.find_one *args, transformer: builder
  end

  def find(*args)
    @collection.find *args, transformer: builder
  end

  private
    def builder
      proc do |result|
        @klass.new.tap do |model|
          model[:id] = result.delete('_id') if model.respond_to?(:id)
          result.each do |field,value|
            model[field] = value if model.respond_to? field
          end
        end
      end
    end
    def process(model)
      fields = {}
      model.each_pair { |field,value| fields[field] = value unless field == :id }
      fields
    end
end
