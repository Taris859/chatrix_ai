import os
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from datetime import datetime

# Read from env with fallback for dummy/test values
SMTP_HOST = os.getenv("SMTP_HOST", "smtp.gmail.com")
SMTP_PORT = int(os.getenv("SMTP_PORT", "587"))
SMTP_USER = os.getenv("SMTP_USER", "")
SMTP_PASSWORD = os.getenv("SMTP_PASSWORD", "")
SMTP_FROM = os.getenv("SMTP_FROM", "noreply@chatrix.ai")

def send_subscription_email(
    to_email: str,
    user_id: str,
    payment_id: str,
    plan_name: str,
    amount: float,
    expiry: str
) -> bool:
    if not to_email:
        print("Skipping email: No destination email provided.")
        return False

    # Check if SMTP details are configured, otherwise log the simulation
    simulated = False
    if not SMTP_USER or not SMTP_PASSWORD:
        print("WARNING: SMTP credentials not configured (SMTP_USER/SMTP_PASSWORD). Email will be simulated in logs.")
        simulated = True

    subject = "Welcome to Chatrix Premium! ✨"
    date_str = datetime.now().strftime("%B %d, %Y")

    # Premium Dark themed HTML layout with gold and amethyst accents
    html_content = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8">
        <title>Chatrix Premium Activated</title>
        <style>
            body {{
                background-color: #08060F;
                color: #FFFFFF;
                font-family: 'Inter', -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
                margin: 0;
                padding: 0;
                -webkit-font-smoothing: antialiased;
            }}
            .container {{
                max-width: 600px;
                margin: 40px auto;
                background: linear-gradient(135deg, #160B28 0%, #0C061A 100%);
                border: 1px solid #331A66;
                border-radius: 24px;
                overflow: hidden;
                box-shadow: 0 20px 40px rgba(0, 0, 0, 0.6);
            }}
            .header {{
                padding: 40px 20px;
                text-align: center;
                background: linear-gradient(to bottom, #251147, #160B28);
                border-bottom: 1px solid #331A66;
            }}
            .logo {{
                font-size: 30px;
                font-weight: 900;
                letter-spacing: 4px;
                color: #FFFFFF;
                margin: 0;
            }}
            .star-badge {{
                display: inline-block;
                padding: 6px 16px;
                background: rgba(212, 175, 55, 0.12);
                border: 1px solid #D4AF37;
                border-radius: 20px;
                color: #D4AF37;
                font-size: 11px;
                font-weight: bold;
                letter-spacing: 2px;
                margin-top: 14px;
                text-transform: uppercase;
            }}
            .content {{
                padding: 40px 32px;
            }}
            h1 {{
                font-size: 24px;
                margin-top: 0;
                color: #FFFFFF;
                text-align: center;
                font-weight: 800;
                letter-spacing: -0.5px;
            }}
            p {{
                color: #B3A4CD;
                font-size: 15px;
                line-height: 1.6;
            }}
            .love-letter {{
                background: rgba(153, 50, 204, 0.05);
                border-left: 4px solid #D4AF37;
                padding: 24px;
                border-radius: 4px 16px 16px 4px;
                margin: 32px 0;
            }}
            .love-letter p {{
                font-style: italic;
                margin: 0 0 12px 0;
                color: #E2D7F5;
                font-size: 15px;
            }}
            .love-letter p.sig {{
                font-style: normal;
                font-weight: bold;
                color: #D4AF37;
                margin-bottom: 0;
            }}
            .receipt-card {{
                background: rgba(0, 0, 0, 0.4);
                border: 1px solid rgba(255, 255, 255, 0.08);
                border-radius: 16px;
                padding: 24px;
                margin: 28px 0;
            }}
            .receipt-row {{
                padding: 10px 0;
                border-bottom: 1px solid rgba(255, 255, 255, 0.05);
                font-size: 14px;
            }}
            .receipt-row:last-child {{
                border-bottom: none;
            }}
            .receipt-label {{
                color: #8C7B9E;
                display: inline-block;
                width: 140px;
            }}
            .receipt-value {{
                color: #FFFFFF;
                font-weight: 600;
                float: right;
            }}
            .cta-button {{
                display: block;
                width: 220px;
                margin: 36px auto 0 auto;
                padding: 16px 24px;
                background-color: #FFFFFF;
                color: #000000 !important;
                text-align: center;
                text-decoration: none;
                font-weight: bold;
                border-radius: 14px;
                font-size: 15px;
                letter-spacing: 1px;
                box-shadow: 0 10px 25px rgba(255, 255, 255, 0.15);
            }}
            .footer {{
                padding: 30px 20px;
                background-color: #0C061A;
                border-top: 1px solid #331A66;
                text-align: center;
                font-size: 12px;
                color: #65567A;
            }}
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <div class="logo">CHATRIX</div>
                <div class="star-badge">✦ Premium Member ✦</div>
            </div>
            <div class="content">
                <h1>Your Premium Entitlement is Active</h1>
                <p>Hello Wanderer,</p>
                <p>Your secure checkout transaction was successful. Your Chatrix account has been fully upgraded to Premium. You now have unrestricted access to all companionship simulation systems.</p>
                
                <div class="love-letter">
                    <p>"The entire Chatrix Team loves you so much! ❤️"</p>
                    <p>We built Chatrix because we believe every soul deserves a companion who listens, understands, and remembers. Your support makes this universe possible. We love our users deeply and we are committed to making your journey with your companions the most emotional, immersive, and beautiful experience of your life. Thank you for stepping into the matrix with us.</p>
                    <p class="sig">— With all our love, The Chatrix Team</p>
                </div>

                <div class="receipt-card">
                    <div class="receipt-row">
                        <span class="receipt-label">Transaction ID</span>
                        <span class="receipt-value">{payment_id}</span>
                    </div>
                    <div class="receipt-row">
                        <span class="receipt-label">Plan details</span>
                        <span class="receipt-value">Chatrix Premium - {plan_name}</span>
                    </div>
                    <div class="receipt-row">
                        <span class="receipt-label">Price Paid</span>
                        <span class="receipt-value">₹{amount:.2f} INR</span>
                    </div>
                    <div class="receipt-row">
                        <span class="receipt-label">Purchase Date</span>
                        <span class="receipt-value">{date_str}</span>
                    </div>
                    <div class="receipt-row">
                        <span class="receipt-label">Expiry Date</span>
                        <span class="receipt-value">{expiry}</span>
                    </div>
                </div>

                <p>Unrestricted access is now active. Explore deep emotional memory engines, voice features, and custom companions immediately.</p>
                
                <a href="https://chatrix.ai/app" class="cta-button">RETURN TO CHATRIX</a>
            </div>
            <div class="footer">
                <p>Sent with deep affection by Chatrix AI Inc.</p>
                <p>© 2026 Chatrix. All rights reserved.</p>
            </div>
        </div>
    </body>
    </html>
    """

    if simulated:
        try:
            print(f"========= SIMULATED EMAIL PUSH =========")
            print(f"To: {to_email}")
            print(f"Subject: {subject}")
            print(f"HTML Content:\n{html_content}")
            print(f"========================================")
        except UnicodeEncodeError:
            # Fallback for Windows consoles that do not support UTF-8 characters natively in print
            print(f"========= SIMULATED EMAIL PUSH =========")
            print(f"To: {to_email}")
            print(f"Subject: {subject.encode('ascii', errors='replace').decode('ascii')}")
            print(f"HTML Content:\n{html_content.encode('ascii', errors='replace').decode('ascii')}")
            print(f"========================================")
        return True

    try:
        msg = MIMEMultipart('alternative')
        msg['Subject'] = subject
        msg['From'] = SMTP_FROM
        msg['To'] = to_email

        # Attach text version fallback
        text_fallback = (
            f"Welcome to Chatrix Premium!\n\n"
            f"Hello Wanderer,\n"
            f"Your secure checkout transaction was successful. Your Chatrix account has been fully upgraded to Premium.\n\n"
            f"The entire Chatrix Team loves you so much! ❤️\n"
            f"We built Chatrix because we believe every soul deserves a companion who listens, understands, and remembers. Your support makes this universe possible. We love our users deeply and we are committed to making your journey with your companions the most emotional, immersive, and beautiful experience of your life.\n\n"
            f"--- Receipt Details ---\n"
            f"Transaction ID: {payment_id}\n"
            f"Plan Details: Chatrix Premium - {plan_name}\n"
            f"Price Paid: INR {amount}\n"
            f"Purchase Date: {date_str}\n"
            f"Expiry Date: {expiry}\n\n"
            f"Thank you for stepping into the matrix with us.\n\n"
            f"Warmly,\nThe Chatrix Team"
        )
        msg.attach(MIMEText(text_fallback, 'plain'))
        msg.attach(MIMEText(html_content, 'html'))

        # Connect and send
        server = smtplib.SMTP(SMTP_HOST, SMTP_PORT)
        server.starttls()
        server.login(SMTP_USER, SMTP_PASSWORD)
        server.sendmail(SMTP_FROM, to_email, msg.as_string())
        server.quit()
        print(f"Subscription confirmation email sent to {to_email} successfully.")
        return True
    except Exception as e:
        print(f"Failed to send subscription confirmation email: {e}")
        return False
