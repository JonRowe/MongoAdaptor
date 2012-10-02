require 'mongo_adaptor'

describe 'db setup' do
  let(:config) { Mongo::Configure.from_database 'mongo_adaptor_test' }

  before do
    config
  end

  it 'uses the configured database' do
    MongoAdaptor.db.name.should == 'mongo_adaptor_test'
  end

end
