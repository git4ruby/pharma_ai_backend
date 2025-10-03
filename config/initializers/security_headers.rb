# Security headers configuration for HIPAA compliance
# Protects against XSS, clickjacking, MIME sniffing, and other attacks

Rails.application.config.action_dispatch.default_headers = {
  # Prevent page from being displayed in iframe (clickjacking protection)
  'X-Frame-Options' => 'DENY',

  # Prevent MIME type sniffing
  'X-Content-Type-Options' => 'nosniff',

  # Enable XSS filtering in browsers
  'X-XSS-Protection' => '1; mode=block',

  # Referrer policy - don't send referrer to external sites
  'Referrer-Policy' => 'strict-origin-when-cross-origin',

  # Permissions policy - restrict browser features
  'Permissions-Policy' => 'geolocation=(), microphone=(), camera=()',

  # Content Security Policy - prevent XSS and injection attacks
  'Content-Security-Policy' => [
    "default-src 'self'",
    "script-src 'self'",
    "style-src 'self' 'unsafe-inline'",  # Allow inline styles for now
    "img-src 'self' data: https:",
    "font-src 'self' data:",
    "connect-src 'self'",
    "frame-ancestors 'none'",
    "base-uri 'self'",
    "form-action 'self'"
  ].join('; ')
}

# HSTS (HTTP Strict Transport Security) - force HTTPS
# Only enable in production to avoid issues in development
if Rails.env.production?
  Rails.application.config.force_ssl = true
  Rails.application.config.ssl_options = {
    hsts: {
      expires: 1.year,
      subdomains: true,
      preload: true
    }
  }
end
