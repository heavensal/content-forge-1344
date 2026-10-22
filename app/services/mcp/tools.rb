module Mcp
  class Tools
    class Forbidden < StandardError; end
    TYPES = { type: "string", enum: Content::FIELDS.keys }.freeze
    ID = { type: "integer", minimum: 1 }.freeze

    def self.definitions
      [
        definition("list_websites", "List your active websites. Never returns website API tokens or webhook settings.", {}),
        definition("list_content", "List content for one authorized website (up to 50 records per page).", { website_id: ID, content_type: TYPES, after_id: ID }, %w[website_id content_type]),
        definition("get_content", "Read one content record, including its current publication state.", { website_id: ID, content_type: TYPES, record_id: ID }, %w[website_id content_type record_id]),
        definition("prepare_change", "Prepare create/update/delete/publish for articles, reviews or FAQs. Does NOT apply or publish. Show the returned approval URL to the user; they must review and approve in contentForge. New content is a draft; publish is a separate proposal. Never invent customer reviews. Reuse request_key only when retrying the identical request.", {
          website_id: ID, content_type: TYPES, record_id: ID,
          operation: { type: "string", enum: %w[create update delete publish] },
          request_key: { type: "string", minLength: 1, maxLength: 100 },
          attributes: { type: "object", additionalProperties: false, properties: {
            title: { type: "string" }, slug: { type: "string" }, description: { type: "string" },
            content: { type: "string" }, locale: { type: "string", enum: %w[fr en] },
            author: { type: "string" }, rating: { type: "integer", minimum: 1, maximum: 5 },
            position: { type: "integer", minimum: 0 }, question: { type: "string" }, answer: { type: "string" }
          } }
        }, %w[website_id content_type operation request_key], write: true),
        definition("get_change", "Check whether your proposal was approved. Applied means saved, not proof of a completed website rebuild.", { change_id: ID }, %w[change_id])
      ]
    end

    def self.definition(name, description, properties, required = [], write: false)
      { name: name, description: description,
        inputSchema: { type: "object", properties: properties, required: required, additionalProperties: false },
        annotations: { readOnlyHint: !write, destructiveHint: false, idempotentHint: true, openWorldHint: false },
        securitySchemes: [ { type: "oauth2", scopes: write ? %w[content:read content:write] : %w[content:read] } ] }
    end

    def initialize(context)
      @user, @scopes = context.user, context.scopes
    end

    def call(name, args)
      require_scope!("content:read")
      definition = self.class.definitions.find { |item| item[:name] == name }
      raise ArgumentError, "Unknown tool" unless definition
      validate_arguments!(definition[:inputSchema], args)
      if name == "list_websites"
        return Content.websites(@user).order(:id).limit(100).as_json(only: %i[id name domain default_locale])
      end
      if name == "get_change"
        change = McpChange.where(user: @user).find(args.fetch("change_id"))
        Content.websites(@user).find(change.website_id)
        return change_json(change)
      end
      site = Content.websites(@user).find(args.fetch("website_id"))
      type = args.fetch("content_type")
      records = Content.scope(site, type)
      case name
      when "list_content"
        list = records.where("id > ?", args.fetch("after_id", 0)).order(:id).limit(51).to_a
        { data: list.first(50).map { |r| Content.serialize(r, type) }, next_after_id: list.size > 50 ? list[49].id : nil }
      when "get_content"
        Content.serialize(records.find(args.fetch("record_id")), type)
      when "prepare_change"
        prepare(site, type, records, args)
      end
    end

    private

    def validate_arguments!(schema, args)
      raise ArgumentError, "Arguments must be an object" unless args.is_a?(Hash)
      properties = schema.fetch(:properties).stringify_keys
      raise ArgumentError, "Unknown arguments" if (args.keys - properties.keys).any?
      raise ArgumentError, "Missing arguments" if (schema.fetch(:required) - args.keys).any?
      args.each do |key, value|
        rule = properties.fetch(key)
        valid = case rule[:type]
        when "integer" then value.is_a?(Integer) && value >= rule.fetch(:minimum, 0)
        when "string" then value.is_a?(String) && value.length.between?(rule.fetch(:minLength, 0), rule.fetch(:maxLength, 100_000))
        when "object" then value.is_a?(Hash)
        end
        valid &&= rule[:enum].include?(value) if rule[:enum]
        raise ArgumentError, "Invalid #{key}" unless valid
      end
    end

    def require_scope!(scope)
      raise Forbidden, "Missing scope #{scope}" unless @scopes.include?(scope)
    end

    def prepare(site, type, records, args)
      require_scope!("content:write")
      operation = args.fetch("operation")
      raise ArgumentError, "record_id is not allowed for create" if operation == "create" && args.key?("record_id")
      payload = Content.attributes(type, args.fetch("attributes", {}))
      raise ArgumentError, "No attributes allowed for this operation" if %w[delete publish].include?(operation) && payload.any?
      requested_id = operation == "create" ? nil : args.fetch("record_id")
      @user.with_lock do
        # Serialize idempotency checks for one user, including concurrent retries.
        existing = McpChange.find_by(user: @user, request_key: args.fetch("request_key"))
        if existing
          same = existing.website_id == site.id && existing.content_type == type && existing.operation == operation &&
            (operation == "create" || existing.record_id == requested_id) && same_request?(existing.payload, payload)
          raise ArgumentError, "request_key already used for different input" unless same
          return change_json(existing)
        end
        site = Content.websites(@user).find(site.id)
        record = operation == "create" ? Content.scope(site, type).build : Content.scope(site, type).find(requested_id)
        require_scope!("content:publish") if operation == "publish" || record.published?
        base_digest = operation == "create" ? nil : Content.digest(record, type)
        record.assign_attributes(payload) if %w[create update].include?(operation)
        record.assign_attributes(status: "published", published_at: Time.current) if operation == "publish"
        raise ActiveRecord::RecordInvalid, record unless operation == "delete" || record.valid?
        payload = with_create_defaults(type, payload, record) if operation == "create"
        change = McpChange.create!(user: @user, website: site, request_key: args.fetch("request_key"),
          content_type: type, operation: operation, record_id: requested_id, payload: payload,
          base_digest: base_digest, expires_at: 30.minutes.from_now)
        change_json(change)
      end
    end

    def same_request?(stored, incoming)
      extras = stored.keys - incoming.keys
      extras.all? { |key| %w[locale slug].include?(key) } && stored.except(*extras) == incoming
    end

    def with_create_defaults(type, payload, record)
      defaults = {}
      defaults["locale"] = record.locale if !payload.key?("locale") && record.locale.present?
      if Content::FIELDS.fetch(type).include?("slug") && !payload.key?("slug") && record.slug.present?
        defaults["slug"] = record.slug
      end
      defaults.empty? ? payload : payload.merge(defaults)
    end

    def change_json(change)
      { change_id: change.id, operation: change.operation, website_id: change.website_id,
        record_id: change.record_id, applied: change.applied_at?, expires_at: change.expires_at.iso8601,
        approval_url: "#{Settings.base_url}/mcp/changes/#{change.id}" }
    end
  end
end
