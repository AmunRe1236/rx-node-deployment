<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>🎩 GENTLEMAN - E-Mail Bestätigung</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background-color: #f5f5f5;
            margin: 0;
            padding: 20px;
        }
        .container {
            max-width: 600px;
            margin: 0 auto;
            background: white;
            border-radius: 12px;
            box-shadow: 0 4px 12px rgba(0,0,0,0.1);
            overflow: hidden;
        }
        .header {
            background: linear-gradient(135deg, #007bff, #0056b3);
            color: white;
            padding: 30px;
            text-align: center;
        }
        .logo {
            font-size: 48px;
            margin-bottom: 10px;
        }
        .content {
            padding: 30px;
        }
        .button {
            display: inline-block;
            padding: 15px 30px;
            background: #007bff;
            color: white;
            text-decoration: none;
            border-radius: 8px;
            font-weight: bold;
            margin: 20px 0;
        }
        .button:hover {
            background: #0056b3;
        }
        .footer {
            background: #f8f9fa;
            padding: 20px;
            text-align: center;
            font-size: 12px;
            color: #666;
        }
        .code-box {
            background: #f8f9fa;
            border: 2px dashed #007bff;
            border-radius: 8px;
            padding: 20px;
            text-align: center;
            margin: 20px 0;
            font-family: monospace;
            font-size: 18px;
            letter-spacing: 2px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="logo">🎩</div>
            <h1>GENTLEMAN Homelab</h1>
            <p>E-Mail Bestätigung</p>
        </div>
        
        <div class="content">
            <h2>Hallo ${user.firstName!""}!</h2>
            
            <p>Willkommen bei GENTLEMAN Homelab. Bitte bestätigen Sie Ihre E-Mail-Adresse, um Ihr Konto zu aktivieren.</p>
            
            <div style="text-align: center;">
                <a href="${link}" class="button">
                    ✅ E-Mail bestätigen
                </a>
            </div>
            
            <p>Oder kopieren Sie diesen Link in Ihren Browser:</p>
            <div class="code-box">
                ${link}
            </div>
            
            <p><strong>Wichtige Hinweise:</strong></p>
            <ul>
                <li>Dieser Link ist ${linkExpirationFormatter(linkExpiration)} gültig</li>
                <li>Falls Sie diese E-Mail nicht angefordert haben, ignorieren Sie sie einfach</li>
                <li>Ihr Konto wird erst nach der Bestätigung aktiviert</li>
            </ul>
            
            <p>Nach der Bestätigung haben Sie Zugriff auf:</p>
            <ul>
                <li>🔐 Keycloak Account Management</li>
                <li>📁 Nextcloud File Storage</li>
                <li>📊 Grafana Monitoring</li>
                <li>🎬 Jellyfin Media Server</li>
                <li>🏠 Home Assistant</li>
            </ul>
        </div>
        
        <div class="footer">
            <p>Mit freundlichen Grüßen,<br>
            Ihr GENTLEMAN System</p>
            <p>🎩 Wo Eleganz auf Funktionalität trifft</p>
            <hr style="border: none; border-top: 1px solid #eee; margin: 20px 0;">
            <p>Diese E-Mail wurde automatisch generiert. Bitte antworten Sie nicht auf diese E-Mail.</p>
        </div>
    </div>
</body>
</html> 