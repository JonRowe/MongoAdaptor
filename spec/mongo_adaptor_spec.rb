require 'mongo_adaptor'

describe 'adapting structs into mongo' do
  before do
    Mongo::Configure.from_database 'mongo_adaptor_test'
  end

  describe 'db setup' do
    it 'uses the configured database' do
      MongoAdaptor.db.name.should == 'mongo_adaptor_test'
    end
  end

  describe 'inserting a blank model' do
    let(:adaptor)    { MongoAdaptor.new 'test_collection', nil }
    let(:model)      { Struct.new(:name,:other,:_id).new('Test Model','Some Data','fake key') }
    let(:collection) { Mongo::Configure.current.load.collection 'test_collection' }
    let(:data)       { collection.find({}).to_a[-1] }

    after do
      Mongo::Configure.current.load.collections.select { |c| c.name !~ /^system\./ }.each &:remove
    end

    subject { adaptor.insert model }

    it 'changes the number of items in the collection' do
      expect { subject }.to change { collection.size }.by(1)
    end
    it 'generates an _id, ignoring any set key' do
      subject
      data['_id'].should be_a BSON::ObjectId
    end
    it 'sets my fields and values' do
      subject
      data['name'].should  == 'Test Model'
      data['other'].should == 'Some Data'
    end
  end
end
