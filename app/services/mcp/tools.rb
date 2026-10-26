module Mcp
  class Tools
    class Forbidden < StandardError; end
    TYPES = { type: "string", enum: Content::FIELDS.keys, description: "Content collection: articles, reviews or faqs." }.freeze
    ID = { type: "integer", minimum: 1, description: "ID returned by list_websites for a website assigned to the signed-in user." }.freeze
    TITLES = {
      "list_websites" => "List my websites",
      "list_content" => "List website content",
      "get_content" => "Read content",
      "prepare_change" => "Prepare a content change",
      "get_change" => "Check a proposed change"
    }.freeze

    def self.definitions
      [
        definition("list_websites", "Use this first to find the active websites assigned to this account and obtain a website_id for other contentForge tools. Returns up to 100 websites; never returns API tokens or webhook settings.", {}),
        definition("list_content", "Use this to find articles, reviews or FAQs on one authorized website, including their IDs and publication states. Returns up to 50 records; use next_after_id as after_id to fetch another page.", { website_id: ID, content_type: TYPES, after_id: { **ID, description: "Optional pagination cursor from the previous list_content response's next_after_id." } }, %w[website_id content_type]),
        definition("get_content", "Use this to inspect one existing article, review or FAQ before editing, deleting or publishing it. Includes its current status and fields.", { website_id: ID, content_type: TYPES, record_id: { **ID, description: "Existing record ID returned by list_content." } }, %w[website_id content_type record_id]),
        definition("prepare_change", "Use this to propose a create, update, delete or publish action for an article, review or FAQ. It does not save or publish anything. Show approval_url to the user for explicit review in contentForge. After an approved create, the record is a draft; publication needs a separate publish proposal and approval. Never invent a customer review.", {
          website_id: ID, content_type: TYPES, record_id: { **ID, description: "Existing content record ID from list_content; required for update, delete and publish; omit for create." },
          operation: { type: "string", enum: %w[create update delete publish], description: "create makes a draft; update changes fields; delete removes a record; publish makes an existing draft public after approval." },
          request_key: { type: "string", minLength: 1, maxLength: 100, description: "Unique key for this proposal. Reuse it only when retrying the exact same request." },
          attributes: { type: "object", additionalProperties: false, properties: {
            title: { type: "string", description: "Article title (articles only)." },
            slug: { type: "string", description: "Optional URL slug (articles and FAQs only); generated when omitted on create." },
            description: { type: "string", description: "Article summary (articles only)." },
            content: { type: "string", description: "Article body as limited HTML, or actual customer review text (articles and reviews only)." },
            locale: { type: "string", enum: %w[fr en], description: "Content language; defaults to the website locale on create." },
            author: { type: "string", description: "Name provided for a real customer review (reviews only)." },
            rating: { type: "integer", minimum: 1, maximum: 5, description: "Review rating from 1 to 5 (reviews only)." },
            position: { type: "integer", minimum: 0, description: "Display order (reviews and FAQs only)." },
            question: { type: "string", description: "FAQ question (FAQs only)." },
            answer: { type: "string", description: "FAQ answer (FAQs only)." }
          }, description: "Fields for create or update only. Supply fields allowed for the selected content_type; omit for delete and publish. Status and published_at cannot be set here." }
        }, %w[website_id content_type operation request_key], write: true),
        definition("get_change", "Use this after presenting approval_url to check whether the user approved a proposal. applied=true means saved in contentForge, not that the website rebuild has completed.", { change_id: { **ID, description: "Proposal ID returned by prepare_change." } }, %w[change_id])
      ]
    end

    def self.definition(name, description, properties, required = [], write: false)
      { name: name, title: TITLES.fetch(name), description: description,
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
