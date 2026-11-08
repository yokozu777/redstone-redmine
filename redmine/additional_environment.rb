# ActiveStorage для redmine_dmsf v5
if File.directory?(Rails.root.join('plugins', 'redmine_dmsf'))
  config.active_storage.service = :local
end

# Тема Opale по умолчанию при первом запуске
Rails.application.config.after_initialize do
  if defined?(Setting) && Setting.table_exists? && Setting['ui_theme'].blank? &&
     Rails.root.join('public', 'themes', 'opale').directory?
    Setting['ui_theme'] = 'opale'
  end
end

dmsf_middleware = Rails.root.join('plugins', 'redmine_dmsf', 'lib', 'redmine_dmsf', 'webdav', 'custom_middleware.rb')
if dmsf_middleware.file?
  require dmsf_middleware.to_s
  config.middleware.insert_before ActionDispatch::Cookies, RedmineDmsf::Webdav::CustomMiddleware
end