module ApplicationHelper
  def nav_link(label, path, section: nil)
    active = section ? controller_name == section : current_page?(path)
    link_to label, path, class: "nav-link#{' is-active' if active}"
  end

  def status_badge(status)
    tone = case status.to_s
    when "completed", "active", "online" then "good"
    when "failed", "dead", "revoked" then "bad"
    else "pending"
    end
    content_tag :span, status.to_s.humanize, class: "badge badge-#{tone}"
  end

  def pretty_json(value)
    JSON.pretty_generate(value || {})
  end
end
