require 'spec_helper'
require 'securerandom'

module VCAP::Services::ServiceBrokers::V2
  describe CatalogService do
    def build_valid_service_attrs(opts = {})
      {
        'id' => 'broker-provided-service-id',
        'metadata' => {},
        'name' => 'service-name',
        'description' => 'The description of this service',
        'bindable' => true,
        'tags' => [],
        'plans' => [build_valid_plan_attrs],
        'requires' => []
      }.merge(opts.stringify_keys)
    end

    def build_valid_plan_attrs(opts = {})
      @index ||= 0
      @index += 1
      {
        'id' => opts[:id] || "broker-provided-plan-id-#{@index}",
        'metadata' => opts[:metadata] || {},
        'name' => opts[:name] || "service-plan-name-#{@index}",
        'description' => opts[:description] || 'The description of the service plan'
      }
    end

    def build_valid_dashboard_client_attrs(opts={})
      {
        'id' => 'some-id',
        'secret' => 'some-secret',
        'redirect_uri' => 'http://redirect.com'
      }.merge(opts.stringify_keys)
    end

    describe '#initialize' do
      it 'defaults @plan_updateable to false' do
        attrs = build_valid_service_attrs
        service = CatalogService.new(double('broker'), attrs)
        expect(service.plan_updateable).to eq false
      end

      it 'sets @plan_updateable if it is provided in the hash' do
        attrs = build_valid_service_attrs(plan_updateable: true)
        service = CatalogService.new(double('broker'), attrs)
        expect(service.plan_updateable).to eq true
      end
    end

    describe 'validations' do
      it 'validates that @broker_provided_id is a string' do
        attrs = build_valid_service_attrs(id: 123)
        service = CatalogService.new(double('broker'), attrs)
        expect(service).not_to be_valid

        expect(service.errors.messages).to include 'Service id must be a string, but has value 123'
      end

      it 'validates that @broker_provided_id is present' do
        attrs = build_valid_service_attrs
        attrs['id'] = nil
        service = CatalogService.new(double('broker'), attrs)
        expect(service).not_to be_valid

        expect(service.errors.messages).to include 'Service id is required'
      end

      it 'validates that @name is a string' do
        attrs = build_valid_service_attrs(name: 123)
        service = CatalogService.new(double('broker'), attrs)
        expect(service).not_to be_valid

        expect(service.errors.messages).to include 'Service name must be a string, but has value 123'
      end

      it 'validates that @name is present' do
        attrs = build_valid_service_attrs
        attrs['name'] = nil
        service = CatalogService.new(double('broker'), attrs)
        expect(service).not_to be_valid

        expect(service.errors.messages).to include 'Service name is required'
      end

      it 'validates that @description is a string' do
        attrs = build_valid_service_attrs(description: 123)
        service = CatalogService.new(double('broker'), attrs)
        expect(service).not_to be_valid

        expect(service.errors.messages).to include 'Service description must be a string, but has value 123'
      end

      it 'validates that @description is present' do
        attrs = build_valid_service_attrs
        attrs['description'] = nil
        service = CatalogService.new(double('broker'), attrs)
        expect(service).not_to be_valid

        expect(service.errors.messages).to include 'Service description is required'
      end

      it 'validates that @bindable is a boolean' do
        attrs = build_valid_service_attrs(bindable: "true")
        service = CatalogService.new(double('broker'), attrs)
        expect(service).not_to be_valid

        expect(service.errors.messages).to include 'Service "bindable" field must be a boolean, but has value "true"'
      end

      it 'validates that @bindable is present' do
        attrs = build_valid_service_attrs
        attrs['bindable'] = nil
        service = CatalogService.new(double('broker'), attrs)
        expect(service).not_to be_valid

        expect(service.errors.messages).to include 'Service "bindable" field is required'
      end

      it 'validates that @plan_updateable is a boolean' do
        attrs = build_valid_service_attrs(plan_updateable: "true")
        service = CatalogService.new(double('broker'), attrs)
        expect(service).not_to be_valid

        expect(service.errors.messages).to include 'Service "plan_updateable" field must be a boolean, but has value "true"'
      end

      it 'validates that @tags is an array of strings' do
        attrs = build_valid_service_attrs(tags: "a string")
        service = CatalogService.new(double('broker'), attrs)
        expect(service).not_to be_valid

        expect(service.errors.messages).to include 'Service tags must be an array of strings, but has value "a string"'

        attrs = build_valid_service_attrs(tags: [123])
        service = CatalogService.new(double('broker'), attrs)
        expect(service).not_to be_valid

        expect(service.errors.messages).to include 'Service tags must be an array of strings, but has value [123]'
      end

      it 'validates that @requires is an array of strings' do
        attrs = build_valid_service_attrs(requires: "a string")
        service = CatalogService.new(double('broker'), attrs)
        expect(service).not_to be_valid

        expect(service.errors.messages).to include 'Service "requires" field must be an array of strings, but has value "a string"'

        attrs = build_valid_service_attrs(requires: [123])
        service = CatalogService.new(double('broker'), attrs)
        expect(service).not_to be_valid

        expect(service.errors.messages).to include 'Service "requires" field must be an array of strings, but has value [123]'
      end

      it 'validates that @metadata is a hash' do
        attrs = build_valid_service_attrs(metadata: ['list', 'of', 'strings'])
        service = CatalogService.new(double('broker'), attrs)
        expect(service).not_to be_valid

        expect(service.errors.messages).to include 'Service metadata must be a hash, but has value ["list", "of", "strings"]'
      end

      it 'validates that the plans list is present' do
        attrs = build_valid_service_attrs(plans: nil)
        service = CatalogService.new(double('broker'), attrs)
        expect(service).not_to be_valid

        expect(service.errors.messages).to include 'At least one plan is required'
        expect(service.errors.messages).not_to include 'Service plans list must be an array of hashes, but has value nil'
      end

      it 'validates that the plans list is an array' do
        attrs = build_valid_service_attrs(plans: "invalid")
        service = CatalogService.new(double('broker'), attrs)
        expect(service).not_to be_valid

        expect(service.errors.messages).to include 'Service plans list must be an array of hashes, but has value "invalid"'
        expect(service.errors.messages).not_to include 'At least one plan is required'
      end

      it 'validates that the plans list is not empty' do
        attrs = build_valid_service_attrs(plans: [])
        service = CatalogService.new(double('broker'), attrs)
        expect(service).not_to be_valid

        expect(service.errors.messages).to include 'At least one plan is required'
        expect(service.errors.messages).not_to include 'Service plans list must be an array of hashes, but has value nil'
      end

      it 'validates that the plans list is an array of hashes' do
        attrs = build_valid_service_attrs(plans: ["list", "of", "strings"])
        service = CatalogService.new(double('broker'), attrs)
        expect(service).not_to be_valid

        expect(service.errors.messages).to include 'Service plans list must be an array of hashes, but has value ["list", "of", "strings"]'
        expect(service.errors.messages).not_to include 'At least one plan is required'
      end

      it 'validates that the plan ids are all unique' do
        attrs = build_valid_service_attrs(plans: [build_valid_plan_attrs(id: 'id-1'), build_valid_plan_attrs(id: 'id-1')])
        service = CatalogService.new(double('broker'), attrs)
        expect(service).not_to be_valid

        expect(service.errors.messages).to include 'Plan ids must be unique'
      end

      it 'validates that the plan names are all unique' do
        attrs = build_valid_service_attrs(plans: [build_valid_plan_attrs(name: 'same-name'), build_valid_plan_attrs(name: 'same-name')])
        service = CatalogService.new(double('broker'), attrs)
        expect(service).not_to be_valid

        expect(service.errors.messages).to include 'Plan names must be unique within a service'
      end

      it 'validates that the plans are all valid' do
        attrs = build_valid_service_attrs(plans: [build_valid_plan_attrs(name: '')])
        service = CatalogService.new(double('broker'), attrs)
        plan = service.plans.first
        expect(service).not_to be_valid

        expect(service.errors.for(plan)).not_to be_empty
      end

      context 'when the service is valid, except for duplicate plan ids' do
        let(:service) do
          service_attrs = build_valid_service_attrs(
            plans: [
              build_valid_plan_attrs(id: '123', description: ''),
              build_valid_plan_attrs(id: '123')
            ]
          )
          CatalogService.new(double('broker'), service_attrs)
        end
        let(:plan) { service.plans.first }

        it 'validates that the plans are all valid' do
          expect(service).not_to be_valid
          expect(service.errors.for(plan)).not_to be_empty
        end
      end

      context 'when the service is valid, except for duplicate plan names' do
        let(:service) do
          service_attrs = build_valid_service_attrs(
            plans: [
              build_valid_plan_attrs(name: 'the-plan', description: ''),
              build_valid_plan_attrs(name: 'the-plan')
            ]
          )
          CatalogService.new(double('broker'), service_attrs)
        end
        let(:plan) { service.plans.first }

        it 'validates that the plans are all valid' do
          expect(service).not_to be_valid
          expect(service.errors.for(plan)).not_to be_empty
        end
      end

      context 'when dashboard_client attributes are provided' do
        it 'validates that the dashboard_client is a hash' do
          attrs = build_valid_service_attrs(dashboard_client: '1')
          service = CatalogService.new(double('broker'), attrs)
          service.valid?

          expect(service.errors.messages).to include 'Service dashboard client attributes must be a hash, but has value "1"'
        end

        it 'validates that the dashboard_client.id is present' do
          dashboard_client_attrs = build_valid_dashboard_client_attrs(id: nil)
          attrs = build_valid_service_attrs(dashboard_client: dashboard_client_attrs)
          service = CatalogService.new(double('broker'), attrs)
          service.valid?

          expect(service.errors.messages).to include 'Service dashboard client id is required'
        end

        it 'validates that the dashboard_client.id is a string' do
          dashboard_client_attrs = build_valid_dashboard_client_attrs(id: 123)
          attrs = build_valid_service_attrs(dashboard_client: dashboard_client_attrs)
          service = CatalogService.new(double('broker'), attrs)
          service.valid?

          expect(service.errors.messages).to include 'Service dashboard client id must be a string, but has value 123'
        end

        it 'validates that the dashboard_client.secret is present' do
          dashboard_client_attrs = build_valid_dashboard_client_attrs(secret: nil)
          attrs = build_valid_service_attrs(dashboard_client: dashboard_client_attrs)
          service = CatalogService.new(double('broker'), attrs)
          service.valid?

          expect(service.errors.messages).to include 'Service dashboard client secret is required'
        end

        it 'validates that the dashboard_client.secret is a string' do
          dashboard_client_attrs = build_valid_dashboard_client_attrs(secret: 123)
          attrs = build_valid_service_attrs(dashboard_client: dashboard_client_attrs)
          service = CatalogService.new(double('broker'), attrs)
          service.valid?

          expect(service.errors.messages).to include 'Service dashboard client secret must be a string, but has value 123'
        end

        it 'validates that the dashboard_client.redirect_uri is present' do
          dashboard_client_attrs = build_valid_dashboard_client_attrs(redirect_uri: nil)
          attrs = build_valid_service_attrs(dashboard_client: dashboard_client_attrs)
          service = CatalogService.new(double('broker'), attrs)
          service.valid?

          expect(service.errors.messages).to include 'Service dashboard client redirect_uri is required'
        end

        it 'validates that the dashboard_client.redirect_uri is a string' do
          dashboard_client_attrs = build_valid_dashboard_client_attrs(redirect_uri: 123)
          attrs = build_valid_service_attrs(dashboard_client: dashboard_client_attrs)
          service = CatalogService.new(double('broker'), attrs)
          service.valid?

          expect(service.errors.messages).to include 'Service dashboard client redirect_uri must be a string, but has value 123'
        end
      end

      describe '#valid?' do
        let(:broker) { double(:broker) }

        context 'when the service and plan are valid' do
          let(:service) { CatalogService.new(broker, build_valid_service_attrs) }

          it 'is true' do
            expect(service).to be_valid
          end
        end
      end
    end

    describe '#cc_service' do
      let(:service_broker) { VCAP::CloudController::ServiceBroker.make }
      let(:broker_provided_id) { SecureRandom.uuid }
      let(:catalog_service) do
        described_class.new( service_broker,
          'id' => broker_provided_id,
          'name' => 'service-name',
          'description' => 'service description',
          'bindable' => true,
          'plans' => [build_valid_plan_attrs]
        )
      end

      context 'when a Service exists with the same service broker and broker provided id' do
        let!(:cc_service) do
          VCAP::CloudController::Service.make(
            unique_id: broker_provided_id,
            service_broker: service_broker
          )
        end

        it 'is that Service' do
          expect(catalog_service.cc_service).to eq(cc_service)
        end
      end

      context 'when a Service exists with a different service broker, but the same broker provided id' do
        let!(:cc_service) do
          VCAP::CloudController::Service.make(unique_id: broker_provided_id)
        end

        it 'is nil' do
          expect(catalog_service.cc_service).to be_nil
        end
      end
    end
  end
end
