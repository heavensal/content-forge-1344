class McpChange < ApplicationRecord
  belongs_to :user
  belongs_to :website
  validates :request_key, presence: true, length: { maximum: 100 }, uniqueness: { scope: :user_id }
  validates :operation, inclusion: { in: %w[create update delete publish] }
  validates :content_type, inclusion: { in: Mcp::Content::FIELDS.keys }
  validates :expires_at, presence: true

  def apply!(actor)
    # Recheck authorization under row locks, but do not hold them across image
    # downloads. The previous cover is released from Article's after_commit,
    # after the new id is stored, so a rollback cannot delete the live file.
    site = under_apply_lock(actor) { |locked_site, _record| locked_site }
    return self if site == :applied

    attributes = attributes_for_apply(site)
    under_apply_lock(actor) do |_locked_site, record|
      apply_to!(record, attributes)
    end
    self
  end

  private

  def under_apply_lock(actor)
    result = :applied
    actor.with_lock do
      actor.website_memberships.lock.load unless actor.admin?
      site = Mcp::Content.websites(actor).lock.find(website_id)
      with_lock do
        raise ArgumentError, "Not your proposal" unless actor.id == user_id
        unless applied_at?
          raise ArgumentError, "Proposal expired; prepare a new one" if expires_at <= Time.current

          records = Mcp::Content.scope(site, content_type)
          record = operation == "create" ? records.build : records.lock.find(record_id)
          if operation != "create" && Mcp::Content.digest(record, content_type) != base_digest
            raise ArgumentError, "Content changed; prepare a new proposal"
          end
          result = yield(site, record)
        end
      end
    end
    result
  end

  def attributes_for_apply(site)
    return if %w[delete publish].include?(operation)

    attributes = Mcp::Content.attributes(content_type, payload)
    return attributes unless content_type == "articles"

    Mcp::ArticleImages.import!(site, attributes)
  end

  def apply_to!(record, attributes)
    case operation
    when "delete" then record.destroy!
    when "publish" then record.update!(status: "published", published_at: Time.current)
    else
      record.assign_attributes(attributes)
      record.status = "draft" if operation == "create"
      record.save!
    end
    update!(applied_at: Time.current, record_id: record.id)
  end
end
