class McpChange < ApplicationRecord
  belongs_to :user
  belongs_to :website
  validates :request_key, presence: true, length: { maximum: 100 }, uniqueness: { scope: :user_id }
  validates :operation, inclusion: { in: %w[create update delete publish] }
  validates :content_type, inclusion: { in: Mcp::Content::FIELDS.keys }
  validates :expires_at, presence: true

  def apply!(actor)
    # Lock the user, membership and site while rechecking authorization and applying.
    actor.with_lock do
      actor.website_memberships.lock.load unless actor.admin?
      site = Mcp::Content.websites(actor).lock.find(website_id)
      with_lock do
        raise ArgumentError, "Not your proposal" unless actor.id == user_id
        return self if applied_at?
        raise ArgumentError, "Proposal expired; prepare a new one" if expires_at <= Time.current
        records = Mcp::Content.scope(site, content_type)
        record = operation == "create" ? records.build : records.lock.find(record_id)
        if operation != "create" && Mcp::Content.digest(record, content_type) != base_digest
          raise ArgumentError, "Content changed; prepare a new proposal"
        end
        case operation
        when "delete" then record.destroy!
        when "publish" then record.update!(status: "published", published_at: Time.current)
        else
          record.assign_attributes(Mcp::Content.attributes(content_type, payload))
          record.status = "draft" if operation == "create"
          record.save!
        end
        update!(applied_at: Time.current, record_id: record.id)
      end
    end
    self
  end
end
