package services

import (
	"bytes"
	"context"
	"fmt"
	"html/template"
	"mowesport/internal/config"
	"net/smtp"
	"strings"
	"time"
)

type EmailService struct {
	config       *config.Config
	auditService *SecurityAuditService
}

type EmailData struct {
	To          string
	Subject     string
	Body        string
	IsHTML      bool
	Attachments []EmailAttachment
}

type EmailAttachment struct {
	Filename string
	Content  []byte
	MimeType string
}

type WelcomeEmailData struct {
	FirstName         string
	LastName          string
	Email             string
	TemporaryPassword string
	LoginURL          string
	SupportEmail      string
	CompanyName       string
	CityName          string
	SportName         string
	ExpirationHours   int
}

func NewEmailService(cfg *config.Config, auditService *SecurityAuditService) *EmailService {
	return &EmailService{
		config:       cfg,
		auditService: auditService,
	}
}

// SendWelcomeEmail sends a welcome email to newly registered administrators
func (s *EmailService) SendWelcomeEmail(ctx context.Context, data WelcomeEmailData) error {
	// Generate HTML content from template
	htmlBody, err := s.generateWelcomeEmailHTML(data)
	if err != nil {
		return fmt.Errorf("failed to generate email HTML: %w", err)
	}

	// Generate plain text version (for future use)
	_ = s.generateWelcomeEmailText(data)

	// Create email data
	emailData := EmailData{
		To:      data.Email,
		Subject: fmt.Sprintf("Bienvenido a %s - Credenciales de Administrador", data.CompanyName),
		Body:    htmlBody,
		IsHTML:  true,
	}

	// Send email with retry logic
	err = s.sendEmailWithRetry(ctx, emailData, 3)
	if err != nil {
		// Log failed email attempt
		s.auditService.LogSecurityEvent(ctx, SecurityEvent{
			EventType:   "EMAIL_SEND_FAILED",
			Description: "Failed to send welcome email",
			IPAddress:   "127.0.0.1",
			UserAgent:   "System",
			Metadata: map[string]interface{}{
				"recipient": data.Email,
				"error":     err.Error(),
			},
		})
		return fmt.Errorf("failed to send welcome email: %w", err)
	}

	// Log successful email
	s.auditService.LogSecurityEvent(ctx, SecurityEvent{
		EventType:   "WELCOME_EMAIL_SENT",
		Description: "Welcome email sent successfully",
		IPAddress:   "127.0.0.1",
		UserAgent:   "System",
		Metadata: map[string]interface{}{
			"recipient":  data.Email,
			"admin_name": fmt.Sprintf("%s %s", data.FirstName, data.LastName),
			"city":       data.CityName,
			"sport":      data.SportName,
		},
	})

	return nil
}

// SendPasswordResetEmail sends a password reset email
func (s *EmailService) SendPasswordResetEmail(ctx context.Context, email, resetToken, firstName string) error {
	resetURL := fmt.Sprintf("%s/reset-password?token=%s", s.config.FrontendURL, resetToken)

	htmlBody := fmt.Sprintf(`
		<html>
		<body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
			<div style="max-width: 600px; margin: 0 auto; padding: 20px;">
				<h2 style="color: #2c5aa0;">Recuperación de Contraseña</h2>
				<p>Hola %s,</p>
				<p>Has solicitado restablecer tu contraseña. Haz clic en el siguiente enlace para crear una nueva contraseña:</p>
				<p style="text-align: center; margin: 30px 0;">
					<a href="%s" style="background-color: #2c5aa0; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; display: inline-block;">
						Restablecer Contraseña
					</a>
				</p>
				<p><strong>Este enlace expirará en 1 hora.</strong></p>
				<p>Si no solicitaste este cambio, puedes ignorar este email.</p>
				<hr style="margin: 30px 0; border: none; border-top: 1px solid #eee;">
				<p style="font-size: 12px; color: #666;">
					Este es un email automático, por favor no respondas a este mensaje.
				</p>
			</div>
		</body>
		</html>
	`, firstName, resetURL)

	emailData := EmailData{
		To:      email,
		Subject: "Recuperación de Contraseña - Mowe Sport",
		Body:    htmlBody,
		IsHTML:  true,
	}

	return s.sendEmailWithRetry(ctx, emailData, 3)
}

// generateWelcomeEmailHTML generates the HTML template for welcome emails
func (s *EmailService) generateWelcomeEmailHTML(data WelcomeEmailData) (string, error) {
	tmpl := `
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Bienvenido a {{.CompanyName}}</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            line-height: 1.6;
            color: #333;
            margin: 0;
            padding: 0;
            background-color: #f4f4f4;
        }
        .container {
            max-width: 600px;
            margin: 0 auto;
            background-color: #ffffff;
            border-radius: 10px;
            overflow: hidden;
            box-shadow: 0 0 20px rgba(0,0,0,0.1);
        }
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
            text-align: center;
        }
        .header h1 {
            margin: 0;
            font-size: 28px;
            font-weight: 300;
        }
        .content {
            padding: 40px 30px;
        }
        .welcome-box {
            background-color: #f8f9ff;
            border-left: 4px solid #667eea;
            padding: 20px;
            margin: 20px 0;
            border-radius: 5px;
        }
        .credentials-box {
            background-color: #fff3cd;
            border: 1px solid #ffeaa7;
            padding: 20px;
            margin: 20px 0;
            border-radius: 5px;
        }
        .credentials-box h3 {
            color: #856404;
            margin-top: 0;
        }
        .credential-item {
            display: flex;
            justify-content: space-between;
            margin: 10px 0;
            padding: 8px 0;
            border-bottom: 1px solid #f0f0f0;
        }
        .credential-label {
            font-weight: bold;
            color: #555;
        }
        .credential-value {
            font-family: 'Courier New', monospace;
            background-color: #f8f9fa;
            padding: 4px 8px;
            border-radius: 3px;
            font-size: 14px;
        }
        .cta-button {
            display: inline-block;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 15px 30px;
            text-decoration: none;
            border-radius: 25px;
            font-weight: bold;
            text-align: center;
            margin: 20px 0;
            transition: transform 0.2s;
        }
        .cta-button:hover {
            transform: translateY(-2px);
        }
        .info-section {
            background-color: #e8f4fd;
            border-left: 4px solid #3498db;
            padding: 20px;
            margin: 20px 0;
            border-radius: 5px;
        }
        .warning-section {
            background-color: #ffeaa7;
            border-left: 4px solid #f39c12;
            padding: 20px;
            margin: 20px 0;
            border-radius: 5px;
        }
        .footer {
            background-color: #2c3e50;
            color: #ecf0f1;
            padding: 30px;
            text-align: center;
            font-size: 14px;
        }
        .footer a {
            color: #3498db;
            text-decoration: none;
        }
        .steps-list {
            counter-reset: step-counter;
            list-style: none;
            padding: 0;
        }
        .steps-list li {
            counter-increment: step-counter;
            margin: 15px 0;
            padding: 15px;
            background-color: #f8f9fa;
            border-radius: 5px;
            position: relative;
            padding-left: 60px;
        }
        .steps-list li::before {
            content: counter(step-counter);
            position: absolute;
            left: 20px;
            top: 15px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            width: 25px;
            height: 25px;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            font-weight: bold;
            font-size: 12px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>¡Bienvenido a {{.CompanyName}}!</h1>
            <p>Tu cuenta de administrador ha sido creada exitosamente</p>
        </div>
        
        <div class="content">
            <div class="welcome-box">
                <h2>Hola {{.FirstName}} {{.LastName}},</h2>
                <p>Te damos la bienvenida como <strong>Administrador de {{.CityName}}</strong> para el deporte de <strong>{{.SportName}}</strong>.</p>
                <p>Tu cuenta ha sido configurada y ya puedes acceder a la plataforma para gestionar torneos, equipos y jugadores en tu jurisdicción.</p>
            </div>

            <div class="credentials-box">
                <h3>🔐 Credenciales de Acceso</h3>
                <div class="credential-item">
                    <span class="credential-label">Email:</span>
                    <span class="credential-value">{{.Email}}</span>
                </div>
                <div class="credential-item">
                    <span class="credential-label">Contraseña Temporal:</span>
                    <span class="credential-value">{{.TemporaryPassword}}</span>
                </div>
            </div>

            <div style="text-align: center;">
                <a href="{{.LoginURL}}" class="cta-button">Acceder a la Plataforma</a>
            </div>

            <div class="warning-section">
                <h3>⚠️ Importante - Seguridad</h3>
                <ul>
                    <li><strong>Cambia tu contraseña inmediatamente</strong> después del primer acceso</li>
                    <li>Esta contraseña temporal expirará en <strong>{{.ExpirationHours}} horas</strong></li>
                    <li>No compartas estas credenciales con nadie</li>
                    <li>Usa una contraseña segura con al menos 8 caracteres, incluyendo mayúsculas, minúsculas, números y símbolos</li>
                </ul>
            </div>

            <div class="info-section">
                <h3>📋 Próximos Pasos</h3>
                <ol class="steps-list">
                    <li><strong>Inicia sesión</strong> con las credenciales proporcionadas</li>
                    <li><strong>Cambia tu contraseña</strong> por una segura y personal</li>
                    <li><strong>Completa tu perfil</strong> con información adicional</li>
                    <li><strong>Explora la plataforma</strong> y familiarízate con las funciones disponibles</li>
                    <li><strong>Comienza a gestionar</strong> torneos y equipos en tu ciudad</li>
                </ol>
            </div>

            <div class="info-section">
                <h3>🎯 Tus Responsabilidades</h3>
                <p>Como administrador de <strong>{{.CityName}}</strong> para <strong>{{.SportName}}</strong>, podrás:</p>
                <ul>
                    <li>✅ Aprobar y gestionar torneos en tu ciudad</li>
                    <li>✅ Supervisar el registro de equipos y jugadores</li>
                    <li>✅ Gestionar árbitros y personal de apoyo</li>
                    <li>✅ Generar reportes y estadísticas</li>
                    <li>✅ Mantener la integridad de los datos deportivos</li>
                </ul>
            </div>

            <div class="info-section">
                <h3>📞 Soporte y Ayuda</h3>
                <p>Si tienes preguntas o necesitas ayuda, no dudes en contactarnos:</p>
                <ul>
                    <li><strong>Email de Soporte:</strong> <a href="mailto:{{.SupportEmail}}">{{.SupportEmail}}</a></li>
                    <li><strong>Documentación:</strong> Disponible en la plataforma una vez que inicies sesión</li>
                    <li><strong>Video Tutoriales:</strong> Accesibles desde tu panel de administración</li>
                </ul>
            </div>
        </div>

        <div class="footer">
            <p><strong>{{.CompanyName}}</strong></p>
            <p>Transformando el deporte local con tecnología</p>
            <p style="font-size: 12px; margin-top: 20px;">
                Este es un email automático. Por favor no respondas a este mensaje.<br>
                Si tienes problemas, contacta a <a href="mailto:{{.SupportEmail}}">{{.SupportEmail}}</a>
            </p>
        </div>
    </div>
</body>
</html>
	`

	t, err := template.New("welcome").Parse(tmpl)
	if err != nil {
		return "", err
	}

	var buf bytes.Buffer
	err = t.Execute(&buf, data)
	if err != nil {
		return "", err
	}

	return buf.String(), nil
}

// generateWelcomeEmailText generates plain text version of welcome email
func (s *EmailService) generateWelcomeEmailText(data WelcomeEmailData) string {
	return fmt.Sprintf(`
¡Bienvenido a %s!

Hola %s %s,

Te damos la bienvenida como Administrador de %s para el deporte de %s.

CREDENCIALES DE ACCESO:
Email: %s
Contraseña Temporal: %s

IMPORTANTE - SEGURIDAD:
- Cambia tu contraseña inmediatamente después del primer acceso
- Esta contraseña temporal expirará en %d horas
- No compartas estas credenciales con nadie

ACCESO A LA PLATAFORMA:
%s

PRÓXIMOS PASOS:
1. Inicia sesión con las credenciales proporcionadas
2. Cambia tu contraseña por una segura y personal
3. Completa tu perfil con información adicional
4. Explora la plataforma y familiarízate con las funciones
5. Comienza a gestionar torneos y equipos en tu ciudad

SOPORTE:
Si necesitas ayuda, contacta a: %s

Saludos,
Equipo de %s

---
Este es un email automático. Por favor no respondas a este mensaje.
	`,
		data.CompanyName,
		data.FirstName, data.LastName,
		data.CityName, data.SportName,
		data.Email, data.TemporaryPassword,
		data.ExpirationHours,
		data.LoginURL,
		data.SupportEmail,
		data.CompanyName,
	)
}

// sendEmailWithRetry sends email with retry logic
func (s *EmailService) sendEmailWithRetry(ctx context.Context, emailData EmailData, maxRetries int) error {
	var lastErr error

	for attempt := 1; attempt <= maxRetries; attempt++ {
		err := s.sendEmail(ctx, emailData)
		if err == nil {
			return nil
		}

		lastErr = err
		if attempt < maxRetries {
			// Wait before retry (exponential backoff)
			waitTime := time.Duration(attempt*attempt) * time.Second
			select {
			case <-ctx.Done():
				return ctx.Err()
			case <-time.After(waitTime):
				continue
			}
		}
	}

	return fmt.Errorf("failed to send email after %d attempts: %w", maxRetries, lastErr)
}

// sendEmail sends the actual email using SMTP
func (s *EmailService) sendEmail(ctx context.Context, emailData EmailData) error {
	// For development, we'll use a simple SMTP configuration
	// In production, this should use proper SMTP credentials from config

	// Mock email sending for development
	if s.config.Environment == "development" {
		return s.mockEmailSend(emailData)
	}

	// Production SMTP implementation
	return s.sendSMTPEmail(emailData)
}

// mockEmailSend simulates email sending for development
func (s *EmailService) mockEmailSend(emailData EmailData) error {
	fmt.Printf("\n=== MOCK EMAIL SENT ===\n")
	fmt.Printf("To: %s\n", emailData.To)
	fmt.Printf("Subject: %s\n", emailData.Subject)
	fmt.Printf("Is HTML: %t\n", emailData.IsHTML)
	fmt.Printf("Body Length: %d characters\n", len(emailData.Body))
	fmt.Printf("========================\n\n")

	// In development, we can also save the email to a file for inspection
	if s.config.Debug {
		filename := fmt.Sprintf("email_%s_%d.html",
			strings.ReplaceAll(emailData.To, "@", "_at_"),
			time.Now().Unix())
		// Note: In a real implementation, you'd save this to a temp directory
		fmt.Printf("Email content would be saved to: %s\n", filename)
	}

	return nil
}

// sendSMTPEmail sends email using SMTP (production implementation)
func (s *EmailService) sendSMTPEmail(emailData EmailData) error {
	// This is a basic SMTP implementation
	// In production, you should use a proper email service like SendGrid, AWS SES, etc.

	smtpHost := s.config.SMTPHost
	smtpPort := s.config.SMTPPort
	smtpUser := s.config.SMTPUser
	smtpPass := s.config.SMTPPassword

	if smtpHost == "" {
		return fmt.Errorf("SMTP configuration not provided")
	}

	// Create message
	message := s.buildEmailMessage(emailData)

	// SMTP authentication
	auth := smtp.PlainAuth("", smtpUser, smtpPass, smtpHost)

	// Send email
	addr := fmt.Sprintf("%s:%s", smtpHost, smtpPort)
	err := smtp.SendMail(addr, auth, smtpUser, []string{emailData.To}, []byte(message))
	if err != nil {
		return fmt.Errorf("failed to send SMTP email: %w", err)
	}

	return nil
}

// buildEmailMessage builds the email message with proper headers
func (s *EmailService) buildEmailMessage(emailData EmailData) string {
	var message strings.Builder

	// Headers
	message.WriteString(fmt.Sprintf("To: %s\r\n", emailData.To))
	message.WriteString(fmt.Sprintf("Subject: %s\r\n", emailData.Subject))

	if emailData.IsHTML {
		message.WriteString("MIME-Version: 1.0\r\n")
		message.WriteString("Content-Type: text/html; charset=UTF-8\r\n")
	} else {
		message.WriteString("Content-Type: text/plain; charset=UTF-8\r\n")
	}

	message.WriteString("\r\n")
	message.WriteString(emailData.Body)

	return message.String()
}

// TestEmailConfiguration tests the email configuration
func (s *EmailService) TestEmailConfiguration(ctx context.Context) error {
	testEmail := EmailData{
		To:      s.config.SMTPUser, // Send test email to self
		Subject: "Test Email Configuration - Mowe Sport",
		Body:    "This is a test email to verify SMTP configuration is working correctly.",
		IsHTML:  false,
	}

	return s.sendEmail(ctx, testEmail)
}
