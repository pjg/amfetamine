require 'active_model'

module Amfetamine
  class Base
    # Activemodel
    extend ActiveModel::Naming
    extend ActiveModel::Callbacks
    include ActiveModel::Validations
    include ActiveModel::Serialization
    include ActiveModel::Serializers::JSON
    include ActiveModel::Conversion

    #Callbacks
    define_model_callbacks :create, :save, :validation


    # amfetamine
    include Amfetamine::RestHelpers
    include Amfetamine::QueryMethods
    include Amfetamine::Relationships

    # Testing
    include Amfetamine::TestHelpers


    attr_reader :attributes
    attr_accessor :cache_key

    def id=(val)
      @attributes['id'] = val
    end

    def id
      @attributes['id']
    end

    def to_hash
      attributes
    end

    def to_hash_with_head
      {class_name.to_sym => to_hash}
    end


    private :'id='



    def self.amfetamine_attributes(*attrs)
      attrs.each do |attr|
        define_method("#{attr}=") do |arg|
          @attributes[attr.to_s] = arg
        end

        define_method("#{attr}") do
          @attributes[attr.to_s]
        end
      end
    end

    # Sets attributes dynamically
    def set_dynamic_attributes(attrs = [])
      klass = class << self;self end # Get reference to eigenklass

      attrs.each do |attr|
        klass.send(:define_method, "#{attr}=") do |arg|
          @attributes[attr.to_s] = arg
        end

        klass.send(:define_method, "#{attr}") do
          @attributes[attr.to_s]
        end
      end
    end

    def self.amfetamine_configure(hash)
      hash.each do |k,v|
        self.send("#{k.to_s}=", v)
      end
    end

    # Builds an object from JSON, later on will need more (maybe object id? Or should that go in find?)
    # It parses the hash, builds the objects and sets new to false
    def self.build_object(args)
      # Cache corruption guard
      args = normalize_cache_data(args)

      obj = self.new(args)
      obj.tap { |obj| obj.instance_variable_set('@notsaved',false) } # because I don't want a global writer
    end

    def update_attributes_from_response(args)
      # We need to check this. If an api provides new data after an update, it will be set :-)
      # Some apis return "nil" or something like that, so we need to double check its a hash

      # TODO: Remove if statement because validation has been added
      if args && args.is_a?(Hash) && args.has_key?(self.class_name)
        args = args[self.class_name]
        args.each { |k,v| self.send("#{k}=", v); self.attributes[k.to_sym] = v  }
      end
    end

    # Allows you to override the global caching server
    def self.memcached_instance=(value, options={})
      if value.is_a?(Array)
        @cache_server = Amfetamine::Cache.new(value.shift, value.first) # First element is the server, second must be the options
      else
        @cache_server = Amfetamine::Cache.new(value, options)
      end
    end

    def self.disable_caching=(value)
      @disable_caching = value
    end

    # Base method for creating objects
    def initialize(args={})
      super
      @attributes = {}
      self.set_dynamic_attributes(args.keys)
      self.cache_key = self.class.recent_cache_key # Shows how this object was retrieved from cache
      args.each { |k,v| self.send("#{k}=", v) }
      @notsaved = true
      self
    end

    def is_attribute?(attr)
      @attributes.keys.include?(attr.to_sym)
    end

    def persisted?
      !new?
    end

    def to_model
      self
    end

    def to_json(*gen)
      options = {}
      options.merge!(:root => self.class.model_name.element)
      super(self.as_json(options))
    end

    def to_key
      persisted? ? [id] : nil
    end

    def to_param
      persisted? ? id.to_s : nil
    end

    # Checks if object is cached by checking if a SINGULAR request was made to this object.
    def cached?
      self.cache_key ? cache.get(self.cache_key).present? : false
    end

    # Checks if object is cachable
    def self.cacheable?
      if @disable_caching == true
        false
      elsif Amfetamine::Config.disable_caching == true
        false
      else 
        true
      end
    end

    def cacheable?
      self.class.cacheable?
    end

    # Checks to see if an object is valid or not
    def valid?
      errors.clear
      run_callbacks(:validation) do
        run_validations!
      end
    end

    # We need to redefine this so it doesn't check on object_id
    def ==(other)
      return false unless self.id == other.id # Some APIs dont ALWAYS return an ID

      self.attributes.all? do |k,v|
        self.attributes[k] == other.attributes[k]
      end
    end

    def errors
      @errors ||= ActiveModel::Errors.new(self)
    end



    def class_name
      self.class.class_name
    end

    def self.class_name
      self.name.downcase
    end

    protected
    def self.cache
      @cache_server || Amfetamine::Cache
    end

    def cache
      self.class.cache
    end

    # TODO: Refactor > cache, only cache should know if data is valid.
    def self.normalize_cache_data(args)
      # Validation predicates
      raise InvalidCacheData, "Empty data" if args.nil?
      raise InvalidCacheData, "Invalid data: #{args.to_s}" if !args.is_a?(Hash)
      args.stringify_keys!
      args = args[class_name] || args
      # TODO remove [:id], stringify_keys! _should_ nail this.
      raise InvalidCacheData, "No object or ID #{args}"  unless args.present? && (args["id"] || args[:id])
      args
    end
  end
end
