module ApplicationHelper
  def nav_link(label, path, section: nil)
    active = section ? Array(section).include?(controller_name) : current_page?(path)
    link_to label, path, class: "nav-link#{' is-active' if active}"
  end

  def external_link_to(label, url, **options)
    options[:target] = "_blank"
    options[:rel] = "noopener noreferrer"
    options[:aria] = { label: "#{label} (opens in a new tab)" }.merge(options.fetch(:aria, {}))
    link_to label, url, **options
  end

  def status_badge(status)
    tone = case status.to_s
    when "completed", "active", "online", "available" then "good"
    when "failed", "dead", "revoked", "offline" then "bad"
    else "pending"
    end
    content_tag :span, status.to_s.humanize, class: "badge badge-#{tone}"
  end

  def pretty_json(value)
    JSON.pretty_generate(value || {})
  end

  def worker_trust_options
    [
      [ "Owner operated", "owner" ],
      [ "Organization managed", "organization" ],
      [ "Verified provider", "verified" ],
      [ "External provider", "external" ]
    ]
  end

  def worker_trust_label(value)
    worker_trust_options.to_h.invert.fetch(value.to_s, value.to_s.humanize)
  end

  def worker_participation_options
    [ [ "Private capacity", "private" ], [ "Shared capacity", "shared" ] ]
  end

  def worker_pool_access_options
    [ [ "Private pool", "private" ], [ "Shared by grant", "shared" ] ]
  end
end
