require 'mongo_adaptor'

describe 'adapting structs into mongo' do
  before do
    Mongo::Configure.from_database 'mongo_adaptor_test'
  end
  after do
    Mongo::Configure.current.load.collections.select { |c| c.name !~ /^system\./ }.each &:remove
  end

  describe 'db setup' do
    it 'uses the configured database' do
      MongoAdaptor.db.name.should == 'mongo_adaptor_test'
    end
  end

  describe 'useing the adaptor' do
    let(:klass)      { Struct.new :name, :other, :id }
    let(:adaptor)    { MongoAdaptor.new 'test_collection', klass }
    let(:collection) { Mongo::Configure.current.load.collection 'test_collection' }

    describe 'to insert a blank model' do
      let(:model) { klass.new 'Test Model','Some Data','fake key'  }
      let(:data)  { collection.find({}).to_a[-1] }

      subject { adaptor.insert model }

      it 'changes the number of items in the collection' do
        expect { subject }.to change { collection.size }.by(1)
      end
      it 'generates an _id, ignoring any set key' do
        subject
        data['_id'].should be_a BSON::ObjectId
        data['id'].should be_nil
      end
      it 'sets my fields and values' do
        subject
        data['name'].should  == 'Test Model'
        data['other'].should == 'Some Data'
      end
    end

    describe 'update an existing model' do
      let(:model) { klass.new 'Test Model','Some Data' }
      let(:data)  { collection.find({}).to_a[-1] }

      before do
        model.id = collection.insert({ name: 'My Model', other: 'Some Value' })
      end

      subject { adaptor.update model }

      it 'doesnt change the number of items in the collection' do
        expect { subject }.to change { collection.size }.by(0)
      end
      it 'doesnt change the id' do
        expect { subject }.to_not change { collection.find_one['_id'] }
      end
      it 'sets my fields and values' do
        subject
        data['_id'].should == model.id
        data['name'].should  == 'Test Model'
        data['other'].should == 'Some Data'
      end
    end
  end
end
