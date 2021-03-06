unless String.method_defined?(:camelize)
  class String
    # convert "undercore_string" in "UnderscoreString"
    #
    # Method from Rails
    def camelize
      self.gsub(/\/(.?)/) { "::" + $1.upcase }.gsub(/(^|_)(.)/) { $2.upcase }
    end
  end
end

module HeyWatch
  class AttributeHash < Hash
    def initialize(constructor = {})
      if constructor.is_a?(Hash)
        super()
        update(constructor)
      else
        super(constructor)
      end
    end
    
    # Returns an exact copy
    def dup
      AttributeHash.new(self)
    end
    
    # Avoid keeping concrete type in stuff like serialization
    def to_yaml(*args)
      to_hash.to_yaml(*args)
    end
        
    # Convert to a Hash
    def to_hash
      Hash.new(default).merge(self)
    end
    
    # Replace "-" by "_" in all keys of the hash
    def underscore_keys!
      self.keys.each do |k|
        if self[k].is_a?(Hash)
          self[k] = AttributeHash.new(self[k]) 
          self[k] = self[k].underscore_keys!
        end
        self[k.to_s.gsub("-", "_")] = self[k]
        delete(k) if k.to_s =~ /-/
      end
      self
    end
    
    # Cast each value of the hash in the right format (integer, float, time, boolean)
    def type_cast!
      self.keys.each do |k|
        self[k] = self[k].type_cast! if self[k].is_a?(Hash)
        self[k] = self[k].to_i if self[k] =~ /^[0-9]+$/
        self[k] = self[k].to_f if self[k] =~ /^[0-9]+\.[0-9]+$/
        self[k] = Time.parse(self[k]) if self[k] =~ /[a-z]+ [a-z]+ [0-9]+ [0-9]{2}:[0-9]{2}:[0-9]{2} [a-z0-9\+]+ [0-9]{4}/i
        self[k] = true if self[k] == "true"
        self[k] = false if self[k] == "false"
        self[k] = nil if self[k] == {}
      end
      self
    end
    
    # The hash keys are available by calling the method name "key"
    #
    #  h = {"format_id" => 54, "video_id" => 12}
    #  h.format_id
    #  => 54
    def method_missing(m, *args)
      if has_key? m.to_s
        self[m.to_s]
      else
        super
      end
    end    
  end
  
  class ResponseCollection < Array
    def find_with_options(options={})
      collection = self
      if options[:conditions]
        options[:conditions].each_pair do |k,v|
          collection = collection.find_with_conditions(k => v)
        end
      end
      collection.limit(options[:limit]).order(options[:order]).include_heywatch_object(options[:include])
    end
    
    
    # Select HeyWatch#Base object containing the conditions
    #
    #   Format.find(:all).find_with_conditions(:owner => true)
    def find_with_conditions(conditions={})
      return self if conditions.nil? or conditions.empty?
      res = ResponseCollection.new
      self.each do |object|
        object.attributes.each_pair do |k,v|
          if conditions[k.to_sym]
            condition = []
            if not conditions[k.to_sym].is_a?(Regexp) and conditions[k.to_sym].to_s =~ /([<|>|<=|>=|==]+)[\s]*([0-9]+)$/
              conditions[k.to_sym].to_s.split(" and ").each do |c|
                c.match(/([<|>|<=|>=|==]+)[\s]*([0-9]+)$/)
                condition << "#{v} #{$1} #{$2}"
              end
              res << object if eval(condition.join(" and "))
            elsif conditions[k.to_sym].is_a?(Regexp)
              res << object if v =~ conditions[k.to_sym]
            else
              res << object if v == conditions[k.to_sym]
            end
          end
        end
      end
      return res
    end

    def limit(lim=nil)
      return self if lim.nil?
      self[0..lim-1]
    end

    def order(order_str=nil)
      return self if order_str.nil?
      field, sort = order_str.match(/([a-z0-9_]+)([\s+]*[ASC|DESC]*)/i).to_a[1..-1]
      sort = "ASC" if sort.nil? or sort.empty?
      begin
        self.sort do |x,y|
          case sort
          when /ASC/i then x.send(field) <=> y.send(field)
          when /DESC/i then y.send(field) <=> x.send(field)
          end
        end
      rescue
        self
      end
    end
    
    def include_heywatch_object(inc=nil)
      return self if inc.nil?
      self.each {|object| object.include_heywatch_object(inc)}
    end
    
    def to_array
      [] + self
    end
    
    def to_yaml(*args)
      to_array.to_yaml(*args)
    end
  end
end