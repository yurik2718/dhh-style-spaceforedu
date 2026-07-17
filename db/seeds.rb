# bin/rails db:seed
# Fresh database assumed: bin/rails db:schema:load db:seed

# ─────────────────────────────────────────────────────────────
# Production: only ensure the super admin exists — payment
# confirmation and admin notifications depend on this account.
# Demo data below must never reach production (weak passwords).
# ─────────────────────────────────────────────────────────────

if Rails.env.production?
  email    = ENV["ADMIN_EMAIL"]
  password = ENV["ADMIN_PASSWORD"]
  abort "Set ADMIN_EMAIL and ADMIN_PASSWORD to seed the production super admin." if email.to_s.empty? || password.to_s.empty?

  User.find_or_create_by!(email_address: email) do |u|
    u.name                = ENV.fetch("ADMIN_NAME", "Admin")
    u.role                = "super_admin"
    u.locale              = "es"
    u.country             = "ES"
    u.privacy_accepted_at = Time.current
    u.password            = password
  end
  puts "Super admin ensured: #{email}"
  return
end

# ─────────────────────────────────────────────────────────────
# Admin
# ─────────────────────────────────────────────────────────────

admin = User.find_or_create_by!(email_address: "admin@spaceforedu.com") do |u|
  u.name                = "Carlos Herrera"
  u.role                = "super_admin"
  u.locale              = "es"
  u.country             = "ES"
  u.privacy_accepted_at = 1.year.ago
  u.password            = "password"
end

# ─────────────────────────────────────────────────────────────
# Students
# ─────────────────────────────────────────────────────────────

maria = User.find_or_create_by!(email_address: "maria.gonzalez@gmail.com") do |u|
  u.name                = "María González"
  u.locale              = "es"
  u.country             = "AR"
  u.birthday            = Date.new(1995, 3, 12)
  u.phone               = "+54 9 11 2345-6789"
  u.whatsapp            = "+54 9 11 2345-6789"
  u.privacy_accepted_at = 3.months.ago
  u.password            = "password"
end

ivan = User.find_or_create_by!(email_address: "ivan.petrov@mail.ru") do |u|
  u.name                = "Ivan Petrov"
  u.locale              = "ru"
  u.country             = "RU"
  u.birthday            = Date.new(1990, 7, 24)
  u.phone               = "+7 916 123-45-67"
  u.whatsapp            = "+7 916 123-45-67"
  u.privacy_accepted_at = 6.weeks.ago
  u.password            = "password"
end

alejandro = User.find_or_create_by!(email_address: "alejandro.ruiz@hotmail.com") do |u|
  u.name                = "Alejandro Ruiz"
  u.locale              = "es"
  u.country             = "MX"
  u.birthday            = Date.new(1988, 11, 5)
  u.phone               = "+52 55 1234-5678"
  u.whatsapp            = "+52 55 1234-5678"
  u.privacy_accepted_at = 2.months.ago
  u.password            = "password"
end

# Minor — guardian fields required
lucia = User.find_or_create_by!(email_address: "lucia.fernandez@gmail.com") do |u|
  u.name                = "Lucía Fernández"
  u.locale              = "es"
  u.country             = "CO"
  u.birthday            = Date.new(2009, 2, 18)
  u.is_minor            = true
  u.guardian_name       = "Pedro Fernández"
  u.guardian_email      = "pedro.fernandez@gmail.com"
  u.guardian_phone      = "+57 310 987-6543"
  u.guardian_whatsapp   = "+57 310 987-6543"
  u.privacy_accepted_at = 1.month.ago
  u.password            = "password"
end

olga = User.find_or_create_by!(email_address: "olga.smirnova@yandex.ru") do |u|
  u.name                  = "Olga Smirnova"
  u.locale                = "ru"
  u.country               = "RU"
  u.birthday              = Date.new(1985, 9, 30)
  u.phone                 = "+7 495 987-65-43"
  u.privacy_accepted_at   = 4.months.ago
  u.notification_telegram = true
  u.password              = "password"
end

puts "Users: #{User.count}"

# ─────────────────────────────────────────────────────────────
# Homologation requests
# ─────────────────────────────────────────────────────────────

# Draft — María just started, hasn't submitted yet
HomologationRequest.find_or_create_by!(user: maria, subject: "Licenciatura en Psicología") do |r|
  r.plan_key         = "basico"
  r.description      = "Quiero homologar mi título de Licenciatura en Psicología obtenido en la Universidad de Buenos Aires."
  r.status           = "draft"
  r.education_system = "Argentina"
  r.university       = "Universidad de Buenos Aires"
  r.year             = 2018
  r.studies_finished = "yes"
  r.privacy_accepted = true
end

# Awaiting payment — Ivan reviewed, admin approved the case, waiting on payment
ivan_request = HomologationRequest.find_or_create_by!(user: ivan, subject: "Диплом инженера-механика") do |r|
  r.plan_key           = "completo"
  r.description        = "Diploma de Ingeniería Mecánica expedido por la Universidad Técnica Estatal de Moscú (BMSTU)."
  r.status             = "awaiting_payment"
  r.status_changed_at  = 2.days.ago
  r.status_changed_by  = admin.id
  r.education_system   = "Russia"
  r.university         = "Bauman Moscow State Technical University"
  r.year               = 2012
  r.studies_finished   = "yes"
  r.language_knowledge = "B2"
  r.privacy_accepted   = true
end

ivan_conv = Conversation.find_or_create_by!(homologation_request: ivan_request)
if ivan_conv.messages.none?
  ivan_conv.messages.create!(user: admin, body: "Buenos días Ivan. Hemos revisado tu expediente y podemos llevar tu caso con el plan Integral (1 750 €), que incluye la admisión universitaria. Pulsa «Pagar» cuando estés listo y arrancamos.", created_at: 2.days.ago)
  ivan_conv.messages.create!(user: ivan,  body: "Muchas gracias. Pago hoy mismo.", created_at: 1.day.ago)
  ivan_conv.update!(last_message_at: 1.day.ago)

  ivan.notifications.create!(notifiable: ivan_request, title: "Caso aprobado — listo para pagar", body: "Hemos revisado tu solicitud. Realiza el pago para continuar.", created_at: 2.days.ago)
end

# In progress — Alejandro paid, pipeline at redsara, one stage retreated earlier
alejandro_request = HomologationRequest.find_or_create_by!(user: alejandro, subject: "Licenciatura en Administración de Empresas") do |r|
  r.plan_key             = "completo"
  r.description          = "Título universitario en Administración de Empresas expedido por el Tecnológico de Monterrey, Campus Ciudad de México."
  r.status               = "in_progress"
  r.status_changed_at    = 3.weeks.ago
  r.status_changed_by    = admin.id
  r.pipeline_stage       = "redsara"
  r.pipeline_changed_at  = 4.days.ago
  r.pipeline_changed_by  = admin.id
  r.pipeline_notes       = "Retrocedemos a tasas_volantes: el modelo 790 estaba sin firmar. Corregido y avanzamos de nuevo."
  r.payment_confirmed_at = 3.weeks.ago
  r.payment_confirmed_by = admin.id
  r.education_system     = "Mexico"
  r.university           = "Tecnológico de Monterrey"
  r.year                 = 2015
  r.studies_finished     = "yes"
  r.language_knowledge   = "C1"
  r.document_checklist   = { "sol" => true, "vol" => true, "tas" => true, "cer" => true, "tit" => false }
  r.privacy_accepted     = true
end

alejandro_conv = Conversation.find_or_create_by!(homologation_request: alejandro_request)
if alejandro_conv.messages.none?
  alejandro_conv.messages.create!(user: admin,    body: "Alejandro, hemos confirmado tu pago. Arrancamos con la tramitación. Te iremos informando de cada avance.", created_at: 3.weeks.ago)
  alejandro_conv.messages.create!(user: alejandro, body: "Perfecto, muchas gracias. Quedo atento.", created_at: 3.weeks.ago + 4.hours)
  alejandro_conv.messages.create!(user: admin,    body: "Tu solicitud ya ha sido presentada en RedSARA. El plazo ministerial es de cuatro a ocho meses; te avisamos en cuanto haya resolución.", created_at: 4.days.ago)
  alejandro_conv.update!(last_message_at: 4.days.ago, admin_last_read_at: 4.days.ago)

  alejandro.notifications.create!(notifiable: alejandro_request, title: "Solicitud presentada en RedSARA", body: "Tu expediente ha sido presentado ante el Ministerio.", read_at: 3.days.ago, created_at: 4.days.ago)
end

# Awaiting reply — pipeline retreated to documentos, missing apostille on Lucia's certificate
lucia_request = HomologationRequest.find_or_create_by!(user: lucia, subject: "Bachillerato Internacional") do |r|
  r.plan_key             = "basico"
  r.description          = "Homologación de Bachillerato Internacional para acceso a estudios universitarios en España."
  r.status               = "awaiting_reply"
  r.status_changed_at    = 1.week.ago
  r.status_changed_by    = admin.id
  r.pipeline_stage       = "documentos"
  r.pipeline_changed_at  = 1.week.ago
  r.pipeline_changed_by  = admin.id
  r.pipeline_notes       = "Retrocedemos a documentos: el certificado de notas carece de apostilla. Pendiente de que el tutor lo gestione desde Colombia."
  r.payment_confirmed_at = 2.weeks.ago
  r.payment_confirmed_by = admin.id
  r.education_system     = "Colombia"
  r.university           = "Colegio Anglo Colombiano"
  r.year                 = 2024
  r.studies_finished     = "yes"
  r.privacy_accepted     = true
end

lucia_conv = Conversation.find_or_create_by!(homologation_request: lucia_request)
if lucia_conv.messages.none?
  lucia_conv.messages.create!(user: admin, body: "Hola Pedro (tutor de Lucía). El certificado de notas que habéis enviado no está apostillado. Sin la apostilla no podemos continuar. Por favor, gestionadlo y reenviadlo cuando lo tengáis.", created_at: 1.week.ago)
  lucia_conv.messages.create!(user: lucia, body: "Mi padre ya está gestionando la apostilla. Nos han dicho que tardará unos diez días.", created_at: 1.week.ago + 6.hours)
  lucia_conv.update!(last_message_at: 1.week.ago + 6.hours, admin_last_read_at: 1.week.ago + 1.day)

  lucia.notifications.create!(notifiable: lucia_request, title: "Documento pendiente", body: "Necesitamos el certificado de notas apostillado para continuar.", created_at: 1.week.ago)
end

# Resolved — Olga's homologation successfully completed after a full pipeline run
olga_request = HomologationRequest.find_or_create_by!(user: olga, subject: "Licenciatura en Filología Española") do |r|
  r.plan_key             = "premium"
  r.description          = "Título de Filología Española y Latinoamericana expedido por la Universidad Estatal de Moscú (MSU)."
  r.status               = "resolved"
  r.status_changed_at    = 2.months.ago
  r.status_changed_by    = admin.id
  r.pipeline_stage       = "completado"
  r.pipeline_changed_at  = 2.months.ago
  r.pipeline_changed_by  = admin.id
  r.payment_confirmed_at = 9.months.ago
  r.payment_confirmed_by = admin.id
  r.education_system     = "Russia"
  r.university           = "Moscow State University"
  r.year                 = 2007
  r.studies_finished     = "yes"
  r.language_knowledge   = "C2"
  r.language_certificate = "DELE C2"
  r.document_checklist   = { "sol" => true, "vol" => true, "tas" => true, "cer" => true, "tit" => true }
  r.privacy_accepted     = true
end

olga_conv = Conversation.find_or_create_by!(homologation_request: olga_request)
if olga_conv.messages.none?
  olga_conv.messages.create!(user: admin, body: "Buenas noticias, Olga. El Ministerio ha resuelto favorablemente tu solicitud. Recibirás la resolución oficial en los próximos días.", created_at: 2.months.ago)
  olga_conv.messages.create!(user: olga,  body: "Muchísimas gracias a todo el equipo. Ha sido un proceso largo pero ha valido la pena.", created_at: 2.months.ago + 3.hours)
  olga_conv.update!(last_message_at: 2.months.ago + 3.hours, admin_last_read_at: 2.months.ago + 1.day, student_last_read_at: 2.months.ago + 3.hours)

  olga.notifications.create!(notifiable: olga_request, title: "Homologación resuelta favorablemente", body: "El Ministerio ha resuelto tu homologación. Enhorabuena.", read_at: 2.months.ago + 3.hours, created_at: 2.months.ago)
end

# Declined — Maria's earlier request that we couldn't take (degree not eligible for homologation)
declined_request = HomologationRequest.find_or_create_by!(user: maria, subject: "Curso de Diseño Gráfico (no universitario)") do |r|
  r.plan_key          = "basico"
  r.description       = "Curso técnico de diseño gráfico de un año, sin titulación universitaria oficial."
  r.status            = "declined"
  r.status_changed_at = 5.days.ago
  r.status_changed_by = admin.id
  r.education_system  = "Argentina"
  r.university        = "Instituto Superior de Diseño"
  r.year              = 2019
  r.studies_finished  = "yes"
  r.privacy_accepted  = true
end

declined_conv = Conversation.find_or_create_by!(homologation_request: declined_request)
if declined_conv.messages.none?
  declined_conv.messages.create!(user: admin, body: "María, hemos revisado tu titulación. Lamentamos comunicarte que solo se pueden homologar títulos universitarios oficiales reconocidos por el ministerio educativo del país emisor; este curso técnico no es elegible. Te recomendamos consultar opciones de convalidación para formación profesional. No se ha emitido cargo alguno.", created_at: 5.days.ago)
  declined_conv.update!(last_message_at: 5.days.ago)

  maria.notifications.create!(notifiable: declined_request, title: "Solicitud no admitida", body: "Tu titulación no es elegible para homologación. Lee la nota del gestor en el chat.", created_at: 5.days.ago)
end

# ─────────────────────────────────────────────────────────────
# Additional students — coverage for submitted, in_review,
# payment_confirmed, closed, and a stale pipeline case
# ─────────────────────────────────────────────────────────────

sofia = User.find_or_create_by!(email_address: "sofia.ramirez@gmail.com") do |u|
  u.name                = "Sofía Ramírez"
  u.locale              = "es"
  u.country             = "PE"
  u.birthday            = Date.new(1993, 5, 22)
  u.phone               = "+51 999 234-567"
  u.privacy_accepted_at = 2.days.ago
  u.password            = "password"
end

mehmet = User.find_or_create_by!(email_address: "mehmet.yilmaz@gmail.com") do |u|
  u.name                = "Mehmet Yılmaz"
  u.locale              = "en"
  u.country             = "TR"
  u.birthday            = Date.new(1991, 8, 14)
  u.phone               = "+90 532 123-4567"
  u.privacy_accepted_at = 5.days.ago
  u.password            = "password"
end

yuki = User.find_or_create_by!(email_address: "yuki.tanaka@gmail.com") do |u|
  u.name                = "Yuki Tanaka"
  u.locale              = "en"
  u.country             = "JP"
  u.birthday            = Date.new(1989, 4, 3)
  u.phone               = "+81 90 1234-5678"
  u.privacy_accepted_at = 3.weeks.ago
  u.password            = "password"
end

anna = User.find_or_create_by!(email_address: "anna.schmidt@web.de") do |u|
  u.name                = "Anna Schmidt"
  u.locale              = "en"
  u.country             = "DE"
  u.birthday            = Date.new(1986, 12, 9)
  u.phone               = "+49 151 234-56789"
  u.privacy_accepted_at = 4.months.ago
  u.password            = "password"
end

pedro = User.find_or_create_by!(email_address: "pedro.almeida@uol.com.br") do |u|
  u.name                = "Pedro Almeida"
  u.locale              = "es"
  u.country             = "BR"
  u.birthday            = Date.new(1980, 6, 17)
  u.phone               = "+55 11 91234-5678"
  u.privacy_accepted_at = 6.months.ago
  u.password            = "password"
end

dmitry = User.find_or_create_by!(email_address: "dmitry.volkov@yandex.ru") do |u|
  u.name                = "Dmitry Volkov"
  u.locale              = "ru"
  u.country             = "RU"
  u.birthday            = Date.new(1984, 2, 28)
  u.phone               = "+7 921 555-12-34"
  u.privacy_accepted_at = 5.months.ago
  u.password            = "password"
end

# Fresh submission — sits in admin's inbox, no message yet
sofia_request = HomologationRequest.find_or_create_by!(user: sofia, subject: "Licenciatura en Educación Inicial") do |r|
  r.plan_key         = "basico"
  r.description      = "Título de Licenciatura en Educación Inicial expedido por la Pontificia Universidad Católica del Perú."
  r.status           = "submitted"
  r.education_system = "Peru"
  r.university       = "Pontificia Universidad Católica del Perú"
  r.year             = 2017
  r.studies_finished = "yes"
  r.privacy_accepted = true
end

# In review — admin already opened the case and asked a question; student hasn't replied
mehmet_request = HomologationRequest.find_or_create_by!(user: mehmet, subject: "Bachelor's degree in Civil Engineering") do |r|
  r.plan_key           = "completo"
  r.description        = "Civil Engineering degree from Boğaziçi University, Istanbul. Looking to continue Master's in Spain."
  r.status             = "in_review"
  r.status_changed_at  = 1.day.ago
  r.status_changed_by  = admin.id
  r.education_system   = "Turkey"
  r.university         = "Boğaziçi University"
  r.year               = 2014
  r.studies_finished   = "yes"
  r.language_knowledge = "B1"
  r.privacy_accepted   = true
end

mehmet_conv = Conversation.find_or_create_by!(homologation_request: mehmet_request)
if mehmet_conv.messages.none?
  mehmet_conv.messages.create!(user: admin, body: "Hi Mehmet, I'm reviewing your file. Could you upload the apostilled academic transcript? The diploma alone isn't enough for the Ministry.", created_at: 1.day.ago)
  mehmet_conv.update!(last_message_at: 1.day.ago)

  mehmet.notifications.create!(notifiable: mehmet_request, title: "Document needed", body: "Please upload the apostilled academic transcript.", created_at: 1.day.ago)
end

# Payment just confirmed — fresh in pipeline at pago_recibido (newly arrived)
yuki_request = HomologationRequest.find_or_create_by!(user: yuki, subject: "PhD in Molecular Biology") do |r|
  r.plan_key             = "premium"
  r.description          = "Doctorate in Molecular Biology, Kyoto University. Need fast-track for postdoc position in Madrid."
  r.status               = "payment_confirmed"
  r.status_changed_at    = 4.hours.ago
  r.status_changed_by    = admin.id
  r.pipeline_stage       = "pago_recibido"
  r.pipeline_changed_at  = 4.hours.ago
  r.pipeline_changed_by  = admin.id
  r.payment_confirmed_at = 4.hours.ago
  r.payment_confirmed_by = admin.id
  r.education_system     = "Japan"
  r.university           = "Kyoto University"
  r.year                 = 2019
  r.studies_finished     = "yes"
  r.language_knowledge   = "B2"
  r.language_certificate = "DELE B2"
  r.privacy_accepted     = true
end

yuki_conv = Conversation.find_or_create_by!(homologation_request: yuki_request)
if yuki_conv.messages.none?
  yuki_conv.messages.create!(user: admin, body: "Yuki, payment received. Premium plan activated — I'll be your single point of contact. We'll move quickly given your postdoc deadline.", created_at: 4.hours.ago)
  yuki_conv.update!(last_message_at: 4.hours.ago)
end

# Late pipeline — at cotejo_delegacion, full checklist, almost done
anna_request = HomologationRequest.find_or_create_by!(user: anna, subject: "Diplom in Architektur") do |r|
  r.plan_key             = "completo"
  r.description          = "Diplom-Ingenieur Architektur, Technische Universität München. Want to register with the Spanish architects' association."
  r.status               = "in_progress"
  r.status_changed_at    = 3.months.ago
  r.status_changed_by    = admin.id
  r.pipeline_stage       = "cotejo_delegacion"
  r.pipeline_changed_at  = 3.weeks.ago
  r.pipeline_changed_by  = admin.id
  r.payment_confirmed_at = 3.months.ago
  r.payment_confirmed_by = admin.id
  r.education_system     = "Germany"
  r.university           = "Technische Universität München"
  r.year                 = 2010
  r.studies_finished     = "yes"
  r.language_knowledge   = "C1"
  r.document_checklist   = { "sol" => true, "vol" => true, "tas" => true, "cer" => true, "tit" => true }
  r.privacy_accepted     = true
end

anna_conv = Conversation.find_or_create_by!(homologation_request: anna_request)
if anna_conv.messages.none?
  anna_conv.messages.create!(user: admin, body: "Anna, your file is now at the regional Delegation for cross-checking. This is the last administrative step — typically 3 to 6 weeks. I'll let you know as soon as it clears.", created_at: 3.weeks.ago)
  anna_conv.update!(last_message_at: 3.weeks.ago, admin_last_read_at: 3.weeks.ago, student_last_read_at: 3.weeks.ago)
end

# Closed — student stopped responding, admin closed after follow-ups
pedro_request = HomologationRequest.find_or_create_by!(user: pedro, subject: "Bacharelado em Direito") do |r|
  r.plan_key          = "completo"
  r.description       = "Bacharelado em Direito pela Universidade de São Paulo (USP)."
  r.status            = "closed"
  r.status_changed_at = 2.weeks.ago
  r.status_changed_by = admin.id
  r.education_system  = "Brazil"
  r.university        = "Universidade de São Paulo"
  r.year              = 2003
  r.studies_finished  = "yes"
  r.privacy_accepted  = true
end

pedro_conv = Conversation.find_or_create_by!(homologation_request: pedro_request)
if pedro_conv.messages.none?
  pedro_conv.messages.create!(user: admin, body: "Pedro, hace varias semanas que esperamos tus documentos apostillados. Sin movimiento por tu parte cerramos el expediente. Si en el futuro quieres retomar, escríbenos y abrimos uno nuevo.", created_at: 2.weeks.ago)
  pedro_conv.update!(last_message_at: 2.weeks.ago)
end

# Stale pipeline — at traduccion, no movement for 12 days (triggers stale highlight)
dmitry_request = HomologationRequest.find_or_create_by!(user: dmitry, subject: "Магистр компьютерных наук") do |r|
  r.plan_key             = "completo"
  r.description          = "Магистратура по компьютерным наукам, СПбГУ. Нужна омологация для работы в испанской IT-компании."
  r.status               = "in_progress"
  r.status_changed_at    = 2.months.ago
  r.status_changed_by    = admin.id
  r.pipeline_stage       = "traduccion"
  r.pipeline_changed_at  = 12.days.ago
  r.pipeline_changed_by  = admin.id
  r.payment_confirmed_at = 2.months.ago
  r.payment_confirmed_by = admin.id
  r.education_system     = "Russia"
  r.university           = "Saint Petersburg State University"
  r.year                 = 2016
  r.studies_finished     = "yes"
  r.language_knowledge   = "B1"
  r.document_checklist   = { "sol" => true, "vol" => true, "tas" => false, "cer" => true, "tit" => true }
  r.privacy_accepted     = true
end

dmitry_conv = Conversation.find_or_create_by!(homologation_request: dmitry_request)
if dmitry_conv.messages.none?
  dmitry_conv.messages.create!(user: admin, body: "Дмитрий, отправили документы переводчику. Срок — 7-10 дней. Как только получим присяжный перевод — двигаемся дальше.", created_at: 12.days.ago)
  dmitry_conv.update!(last_message_at: 12.days.ago, admin_last_read_at: 12.days.ago, student_last_read_at: 12.days.ago)
end

puts "Requests:      #{HomologationRequest.count}"
puts "Conversations: #{Conversation.count}"
puts "Messages:      #{Message.count}"
puts "Notifications: #{Notification.count}"
puts "Done."
