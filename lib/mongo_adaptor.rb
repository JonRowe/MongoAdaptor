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


  private
    def process(model)
      fields = {}
      model.each_pair { |field,value| fields[field] = value unless field == :id }
      fields
    end
end
