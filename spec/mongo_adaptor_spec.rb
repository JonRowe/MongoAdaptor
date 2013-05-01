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

  describe 'using the adaptor' do
    let(:klass)      { Struct.new :name, :other, :members, :id }
    let(:adaptor)    { MongoAdaptor.new 'test_collection', klass }
    let(:collection) { Mongo::Configure.current.load.collection 'test_collection' }

    describe 'with a new model' do
      let(:model) { klass.new 'Test Model','Some Data','Some Members','fake key'  }
      let(:data)  { collection.find({}).to_a[-1] }

      shared_examples_for 'new model' do
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
          data['members'].should == 'Some Members'
        end
      end

      context 'inserting' do
        subject { adaptor.insert model }
        it_should_behave_like 'new model'
      end
      context 'upserting' do
        subject { adaptor.upsert model, {} }
        it_should_behave_like 'new model'
      end
    end

    describe 'with an existing model' do
      let(:model) { klass.new 'Test Model','Some Data','Some Members' }
      let(:id)    { collection.insert({ :name => 'My Model', :other => 'Some Value', :members => 'Some Members' },{ :safe => true }) }

      before do
        model.id = id
      end

      shared_examples_for 'modifying an existing model' do
        let(:data)  { collection.find({}).to_a[-1] }

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
          data['members'].should == 'Some Members'
        end
      end

      describe 'to update it' do
        subject { adaptor.update model }
        it_should_behave_like 'modifying an existing model'
      end

      describe 'to upsert it' do
        subject { adaptor.upsert model, { :name => 'My Model' } }
        it_should_behave_like 'modifying an existing model'
      end

      describe 'to fetch it' do
        subject { adaptor.fetch({ :_id => id }) }
        it            { should be_a klass }
        its(:id)      { should == id }
        its(:name)    { should == 'My Model' }
        its(:other)   { should == 'Some Value' }
        its(:members) { should == 'Some Members' }
      end

      describe 'to remove it' do
        it 'removes the document matching the selector' do
          adaptor.remove({ :_id => id })
          adaptor.fetch({ :_id => id }).should be_nil
        end
      end
    end

    describe 'finding multiples' do
      before do
        3.times do |i|
          collection.insert({ :name => 'My Model', :other => i },{ :safe => true })
        end
        3.times do |i|
          collection.insert({ :name => 'Other Model', :other => i },{ :safe => true })
        end
      end

      subject { adaptor.find({ :name => 'My Model' }) }

      its(:count) { should == 3 }
      it 'translates all to klass' do
        subject.all? { |k| k.is_a? klass }.should be_true
      end
      it 'gets them all' do
        subject.map(&:other).should == [0,1,2]
      end
    end
  end
end
