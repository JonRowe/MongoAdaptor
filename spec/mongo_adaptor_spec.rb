require 'rspec/its'
require 'mongo_adaptor'

describe 'adapting structs into mongo' do
  before { Mongo::Configure.from_database 'mongo_adaptor_test' }
  after  { Mongo::Configure.current.load.collections.select { |c| c.name !~ /^system\./ }.each &:remove }

  describe 'db setup' do
    it 'uses the configured database' do
      expect(MongoAdaptor.db.name).to eq 'mongo_adaptor_test'
    end

    it 'can be configured' do
      original = MongoAdaptor.db
      MongoAdaptor.db = fake = double
      expect(MongoAdaptor.db).to eq fake
      MongoAdaptor.db = original
    end
  end

  describe 'using the adaptor' do
    let(:klass)      { Struct.new :name, :other, :members, :id }
    let(:adaptor)    { MongoAdaptor.new 'test_collection', klass }
    let(:collection) { Mongo::Configure.current.load.collection 'test_collection' }

    describe 'with a new model' do
      let(:model) { klass.new 'Test Model','Some Data','Some Members','fake key'  }
      let(:data)  { collection.find({}).to_a[-1] }

      shared_examples_for 'creates a document' do
        it 'changes the number of items in the collection' do
          expect { subject }.to change { collection.size }.by(1)
        end
        it 'generates an _id, ignoring any set key' do
          subject
          expect(data['_id']).to be_a BSON::ObjectId
          expect(data['id']).to be_nil
        end
      end
      shared_examples_for 'new model' do
        it_should_behave_like 'creates a document'
        it 'sets my fields and values' do
          subject
          expect(data['name']).to  eq 'Test Model'
          expect(data['other']).to eq 'Some Data'
          expect(data['members']).to eq 'Some Members'
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

      describe 'upserting with a custom operation' do
        subject { adaptor.execute({ :name => 'value' }, { '$push' => { "key" => "value" } }, { :upsert => true }) }
        it_should_behave_like 'creates a document'
        it 'will execute my command' do
          subject
          expect(data['key']).to eq ['value']
        end
      end
    end

    describe 'with an existing model' do
      let(:model) { klass.new 'Test Model','Some Data',['Some Other Members'] }
      let(:id)    { collection.insert({ :name => 'My Model', :other => 'Some Value', :members => ['Some Members'] },{ :w => 1 }) }

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
          expect(data['_id']).to eq model.id
          expect(data['name']).to  eq 'Test Model'
          expect(data['other']).to eq 'Some Data'
          expect(data['members']).to eq ['Some Other Members']
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

      describe 'to update it with a custom operation' do
        let(:data)  { collection.find({}).to_a[-1] }
        subject { adaptor.execute model, "$push" => { "members" => "Some Other Members" } }

        it 'doesnt change the number of items in the collection' do
          expect { subject }.to change { collection.size }.by(0)
        end
        it 'doesnt change the id' do
          expect { subject }.to_not change { collection.find_one['_id'] }
        end
        it 'executes my command' do
          subject
          expect(data['members']).to eq ['Some Members','Some Other Members']
        end
        it 'also can execute my command by query' do
          adaptor.execute({ "name" => 'My Model'}, "$push" => { "members" => "Some Other Members" })
          expect(data['members']).to eq ['Some Members','Some Other Members']
        end
      end

      describe 'to fetch it' do
        subject { adaptor.fetch({ :_id => id }) }
        it            { is_expected.to be_a klass }
        its(:id)      { should == id }
        its(:name)    { should == 'My Model' }
        its(:other)   { should == 'Some Value' }
        its(:members) { should == ['Some Members'] }
      end

      describe 'to remove it' do
        it 'removes the document matching the selector' do
          adaptor.remove({ :_id => id })
          expect(adaptor.fetch({ :_id => id })).to be_nil
        end
      end
    end

    describe 'finding multiples' do
      before do
        3.times do |i|
          collection.insert({ :name => 'My Model', :other => i },{ :w => 1 })
        end
        3.times do |i|
          collection.insert({ :name => 'Other Model', :other => i },{ :w => 1 })
        end
      end

      subject { adaptor.find({ :name => 'My Model' }) }

      its(:count) { should == 3 }
      it 'translates all to klass' do
        expect(subject.all? { |k| k.is_a? klass }).to be true
      end
      it 'gets them all' do
        expect(subject.map(&:other)).to eq [0,1,2]
      end
      it 'will pass along options' do
        expect { adaptor.find({ :name => 'My Model' },{ :fields => { }}) }.to_not raise_error
      end
    end
  end
end
