require 'active_support/inflector'
require 'json'

module Amfetamine
  module RestHelpers

    RESPONSE_STATUSES = { 422 => :errors, 404 => :notfound, 200 => :success, 201 => :created, 500 => :server_error, 406 => :not_acceptable }

    def rest_path(args={})
      self.class.rest_path(args)
    end

    def self.included(base)
      base.extend ClassMethods
    end

    def singular_path(args={})
      self.class.find_path(self.id, args)
    end

    # This method handles the save response
    # TODO: Needs refactoring, now just want to make the test pass =)
    # Making assumption here that when response is nil, it should have possitive result. Needs refactor when slept more
    def handle_response(response)
      case response[:status]
      when :success, :created
        self.instance_variable_set('@notsaved', false)
        true
      when :errors
        Amfetamine.logger.warn "Errors from response\n #{response[:body]}"
        response[:body].each do |attr, error_messages|
          error_messages.each do |msg|
            errors.add(attr.to_sym, msg)
          end
        end
        false
      when :server_error
        Amfetamine.logger.warn "Something went wrong at the remote end."
        false
      end
    end


    module ClassMethods
      def rest_path(params={})
        result = if params[:relationship]
          relationship = params[:relationship]
          "/#{relationship.full_path}"
        else
          "/#{self.name.downcase.pluralize}"
        end

        result = base_uri + result unless params[:no_base_uri]
        result = result + resource_suffix unless params[:no_resource_suffix]
        return result
      end

      def find_path(id, params={})
        params_for_rest_path = params.merge({:no_base_uri => true, :no_resource_suffix => true})
        result = "#{self.rest_path(params_for_rest_path)}/#{id.to_s}"

        result = base_uri + result unless params[:no_base_uri]
        result = result + resource_suffix unless params[:no_resource_suffix]
        return result
      end


      def base_uri
        @base_uri || Amfetamine::Config.base_uri
      end

      # wraps rest requests to the corresponding service
      # *emerging*
      def handle_request(method, path, opts={})
        Amfetamine.logger.warn "Making request to #{path} with #{method} and #{opts.inspect}"
        case method
        when :get
          response = rest_client.get(path, opts)
        when :post
          response = rest_client.post(path, opts)
        when :put
          response = rest_client.put(path, opts)
        when :delete
          response = rest_client.delete(path, opts)
        else
          raise UnknownRESTMethod, "handle_request only responds to get, put, post and delete"
        end
        parse_response(response)
      end

      # Returns a hash with human readable status and parsed body
      def parse_response(response)
        status = RESPONSE_STATUSES.fetch(response.code) { raise "Response not known" }
        raise Amfetamine::RecordNotFound if status == :notfound
        body = if response.body && !(response.body.blank?)
                 response.parsed_response
               else
                 self.to_json
               end
        { :status => status, :body => body }
      end

      def rest_client
        @rest_client || Amfetamine::Config.rest_client
      end

      def resource_suffix
        @resource_suffix || Amfetamine::Config.resource_suffix || ""
      end

      # Allows setting a different rest client per class
      def rest_client=(value)
        raise Amfetamine::ConfigurationInvalid, 'Invalid value for rest_client' if ![:get,:put,:delete,:post].all? { |m| value.respond_to?(m) }
        @rest_client = value
      end

      def resource_suffix=(value)
        raise Amfetamine::ConfigurationInvalid, 'Invalid value for resource suffix' if !value.is_a?(String)
        @resource_suffix = value
      end

      def base_uri=(value)
        raise Amfetamine::ConfigurationInvalid, 'Invalid value for base uri' if !value.is_a?(String)
        @base_uri = value
      end
    end
  end
end
