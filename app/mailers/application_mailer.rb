class ApplicationMailer < ActionMailer::Base
  default from: -> { ENV.fetch("MAILER_FROM", "noreply@1344.fr") }
  layout "mailer"
end
