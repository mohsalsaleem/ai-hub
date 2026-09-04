namespace :platform do
  desc "Create or reset a separate platform operator. Provide EMAIL and PASSWORD."
  task create_operator: :environment do
    email = ENV.fetch("EMAIL")
    password = ENV.fetch("PASSWORD")
    operator = PlatformOperator.find_or_initialize_by(email_address: email.strip.downcase)
    operator.password = password
    operator.active = true
    operator.save!
    operator.platform_sessions.delete_all
    puts "Platform operator #{operator.email_address} is active."
  end

  desc "Disable a platform operator. Provide EMAIL."
  task disable_operator: :environment do
    email = ENV.fetch("EMAIL")
    operator = PlatformOperator.find_by!(email_address: email.strip.downcase)

    if PlatformOperator.where(active: true).where.not(id: operator.id).none?
      abort "Cannot disable the final active platform operator."
    end

    operator.update!(active: false)
    operator.platform_sessions.delete_all
    puts "Disabled platform operator #{operator.email_address}."
  end
end
