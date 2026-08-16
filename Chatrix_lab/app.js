document.addEventListener('DOMContentLoaded', () => {
    
    // --- Mobile Menu Toggle ---
    const mobileToggle = document.getElementById('mobile-toggle');
    const navLinks = document.getElementById('nav-links');
    
    if (mobileToggle && navLinks) {
        mobileToggle.addEventListener('click', () => {
            navLinks.classList.toggle('active');
            mobileToggle.classList.toggle('active');
            
            // Hamburger icon animation toggle
            const spans = mobileToggle.querySelectorAll('span');
            if (mobileToggle.classList.contains('active')) {
                spans[0].style.transform = 'rotate(45deg) translate(6px, 6px)';
                spans[1].style.opacity = '0';
                spans[2].style.transform = 'rotate(-45deg) translate(5px, -5px)';
            } else {
                spans[0].style.transform = 'none';
                spans[1].style.opacity = '1';
                spans[2].style.transform = 'none';
            }
        });
        
        // Close menu when clicking a link
        navLinks.querySelectorAll('a').forEach(link => {
            link.addEventListener('click', () => {
                navLinks.classList.remove('active');
                mobileToggle.classList.remove('active');
                const spans = mobileToggle.querySelectorAll('span');
                spans[0].style.transform = 'none';
                spans[1].style.opacity = '1';
                spans[2].style.transform = 'none';
            });
        });
    }

    // --- ROI Calculator ---
    const trafficInput = document.getElementById('traffic-input');
    const ticketValueInput = document.getElementById('ticket-value');
    const trafficDisplay = document.getElementById('traffic-display');
    const valueDisplay = document.getElementById('value-display');
    
    const leadsGenerated = document.getElementById('leads-generated');
    const revenueGenerated = document.getElementById('revenue-generated');
    const hoursSaved = document.getElementById('hours-saved');

    function calculateROI() {
        if (!trafficInput || !ticketValueInput) return;
        
        const traffic = parseInt(trafficInput.value, 10);
        const customerValue = parseInt(ticketValueInput.value, 10);
        
        // Update range labels
        trafficDisplay.textContent = `${traffic.toLocaleString()} visitors`;
        valueDisplay.textContent = `₹${customerValue.toLocaleString()}`;
        
        // Grounded Calculations:
        // 1. Extra Leads Captured = 1.5% lead capture improvement rate
        const extraLeads = Math.round(traffic * 0.015);
        
        // 2. Additional Monthly Revenue = extra leads * 10% average deal close rate * customer value
        const extraRevenue = Math.round(extraLeads * 0.10 * customerValue);
        
        // 3. Support Hours Saved = 15% query rate * 3 mins saved / 60 mins
        const hours = Math.round((traffic * 0.15 * 3) / 60);
        
        // Update DOM
        if (leadsGenerated) leadsGenerated.textContent = extraLeads;
        if (revenueGenerated) revenueGenerated.textContent = `₹${extraRevenue.toLocaleString()}`;
        if (hoursSaved) hoursSaved.textContent = hours;
    }

    if (trafficInput && ticketValueInput) {
        trafficInput.addEventListener('input', calculateROI);
        ticketValueInput.addEventListener('input', calculateROI);
        calculateROI(); // Initial run
    }

    // --- Consultation Modal Overlay ---
    const modal = document.getElementById('consultation-modal');
    const openModalBtns = document.querySelectorAll('.open-modal-btn');
    const closeModalBtn = document.getElementById('modal-close-btn');
    const consultationForm = document.getElementById('consultation-form');
    const formSuccessMsg = document.getElementById('form-success-msg');
    const formErrorMsg = document.getElementById('form-error-msg');
    const formSubmitBtn = document.getElementById('form-submit-btn');

    function openModal() {
        if (modal) {
            modal.classList.add('active');
            document.body.style.overflow = 'hidden'; // Stop scroll
        }
    }

    function closeModal() {
        if (modal) {
            modal.classList.remove('active');
            document.body.style.overflow = ''; // Resume scroll
            // Reset messages and form after animations clear
            setTimeout(() => {
                if (consultationForm) {
                    consultationForm.reset();
                    consultationForm.style.display = 'flex';
                }
                if (formSuccessMsg) formSuccessMsg.style.display = 'none';
                if (formErrorMsg) formErrorMsg.style.display = 'none';
                if (formSubmitBtn) formSubmitBtn.disabled = false;
            }, 300);
        }
    }

    openModalBtns.forEach(btn => {
        btn.addEventListener('click', openModal);
    });

    if (closeModalBtn) {
        closeModalBtn.addEventListener('click', closeModal);
    }

    if (modal) {
        modal.addEventListener('click', (e) => {
            if (e.target === modal) {
                closeModal();
            }
        });
    }

    // --- AJAX Formspree submission ---
    if (consultationForm) {
        consultationForm.addEventListener('submit', function (ev) {
            ev.preventDefault();
            if (formSubmitBtn) {
                formSubmitBtn.disabled = true;
                const originalText = formSubmitBtn.innerHTML;
                formSubmitBtn.innerHTML = '<span>Submitting leads...</span>';
            }
            
            const data = new FormData(consultationForm);
            fetch(consultationForm.action, {
                method: consultationForm.method,
                body: data,
                headers: {
                    'Accept': 'application/json'
                }
            }).then(response => {
                if (response.ok) {
                    consultationForm.reset();
                    consultationForm.style.display = 'none';
                    if (formSuccessMsg) formSuccessMsg.style.display = 'block';
                    if (formErrorMsg) formErrorMsg.style.display = 'none';
                } else {
                    response.json().then(data => {
                        if (formErrorMsg) {
                            formErrorMsg.style.display = 'block';
                            formErrorMsg.querySelector('p').textContent = data.error || 'There was a problem submitting your form.';
                        }
                    });
                    if (formSubmitBtn) formSubmitBtn.disabled = false;
                }
            }).catch(error => {
                if (formErrorMsg) formErrorMsg.style.display = 'block';
                if (formSubmitBtn) formSubmitBtn.disabled = false;
            });
        });
    }

    // --- Floating Chatbot Widget ---
    const chatbotTrigger = document.getElementById('chatbot-trigger');
    const chatbotWindow = document.getElementById('chatbot-window');
    const chatbotClose = document.getElementById('chatbot-close');
    const chatbotMessages = document.getElementById('chatbot-messages');
    const chatbotChips = document.getElementById('chatbot-chips');

    // Bot messages mapping
    const botReplies = {
        pricing: {
            userText: "💰 Check Pricing",
            botText: "We offer 3 flat-rate packages:<br><br>• <strong>Starter (₹9,999)</strong>: 1-page site, contact form, basic AI bot (3-5 days delivery).<br>• <strong>Growth (₹19,999) ⭐ [Most Popular]</strong>: Multi-section site, AI bot trained on business, lead system, 30 days support (5-7 days delivery).<br>• <strong>Scale (₹29,999)</strong>: Growth + Custom PDF knowledge base, calendar booking system, basic CRM (7-10 days delivery).<br><br>Which package would you like to discuss?",
            actionBtn: `<a href="https://wa.me/919588346601?text=Hi%20Chatrix%20Labs!%20I'm%20discussing%20pricing%20packages%20from%20the%20chatbot%20demo." target="_blank" class="btn btn-whatsapp header-whatsapp" style="margin-top: 10px; width: 100%;">🟢 Discuss Tiers on WhatsApp</a>`
        },
        setup: {
            userText: "⚡ What is the setup time?",
            botText: "Our core promise is <strong>Fast 7-Day Deployment</strong>. <br><br>We map your company data, build the custom agent, test conversations, and deploy it onto your website and WhatsApp Business number within 7 days. No long developer contracts or delays.",
            actionBtn: `<button class="btn btn-primary open-modal-btn" style="margin-top: 10px; width: 100%;">📅 Book Free Consultation</button>`
        },
        whatsapp: {
            userText: "💬 Chatbot Capabilities",
            botText: "The AI Chatbot is trained specifically on your company FAQs, business PDFs, and website data. It resolves up to 70% of general queries instantly, captures leads 24/7, and alerts you via email/sheets immediately when a hot prospect submits their WhatsApp number. No complex coding required!",
            actionBtn: `<a href="https://wa.me/919588346601?text=Hi%20Chatrix%20Labs!%20I'm%20interested%20in%20learning%20more%20about%20your%20custom%20AI%20chatbot." target="_blank" class="btn btn-whatsapp header-whatsapp" style="margin-top: 10px; width: 100%;">💬 Discuss on WhatsApp</a>`
        },
        book: {
            userText: "📅 Book Free Consultation Slot",
            botText: "Awesome! Let's lock in a free 15-minute call. Click below to fill in your contact information directly or ping us on WhatsApp to lock a slot immediately.",
            actionBtn: `<button class="btn btn-primary open-modal-btn" style="margin-top: 10px; width: 100%;">🟢 Open Booking Form</button>`
        }
    };

    if (chatbotTrigger && chatbotWindow) {
        chatbotTrigger.addEventListener('click', () => {
            chatbotWindow.style.display = chatbotWindow.style.display === 'none' ? 'flex' : 'none';
            // Scroll bot messaging log to bottom
            if (chatbotMessages) {
                chatbotMessages.scrollTop = chatbotMessages.scrollHeight;
            }
        });
    }

    if (chatbotClose && chatbotWindow) {
        chatbotClose.addEventListener('click', () => {
            chatbotWindow.style.display = 'none';
        });
    }

    // Handle quick chip clicks
    if (chatbotChips && chatbotMessages) {
        chatbotChips.addEventListener('click', (e) => {
            const chipBtn = e.target.closest('.chip-btn');
            if (!chipBtn) return;
            
            const query = chipBtn.getAttribute('data-query');
            const data = botReplies[query];
            if (!data) return;

            // 1. Disable chips temporarily during reply
            const allChips = chatbotChips.querySelectorAll('.chip-btn');
            allChips.forEach(btn => btn.disabled = true);

            // 2. Append User Message
            const userMsgDiv = document.createElement('div');
            userMsgDiv.className = 'chat-msg user';
            userMsgDiv.innerHTML = `<div class="chat-text">${data.userText}</div>`;
            chatbotMessages.appendChild(userMsgDiv);
            chatbotMessages.scrollTop = chatbotMessages.scrollHeight;

            // 3. Append Bot Typing Indicator
            const typingDiv = document.createElement('div');
            typingDiv.className = 'chat-msg bot typing-msg';
            typingDiv.innerHTML = `
                <div class="chat-avatar">🤖</div>
                <div class="chat-text">
                    <div class="typing-indicator">
                        <span class="typing-dot"></span>
                        <span class="typing-dot"></span>
                        <span class="typing-dot"></span>
                    </div>
                </div>
            `;
            chatbotMessages.appendChild(typingDiv);
            chatbotMessages.scrollTop = chatbotMessages.scrollHeight;

            // 4. Resolve Bot Reply
            setTimeout(() => {
                // Remove typing message
                const typingMsg = chatbotMessages.querySelector('.typing-msg');
                if (typingMsg) typingMsg.remove();

                // Append Real Response
                const botMsgDiv = document.createElement('div');
                botMsgDiv.className = 'chat-msg bot';
                botMsgDiv.innerHTML = `
                    <div class="chat-avatar">🤖</div>
                    <div class="chat-text">
                        ${data.botText}
                        ${data.actionBtn || ''}
                    </div>
                `;
                chatbotMessages.appendChild(botMsgDiv);
                
                // Wire modal button if included inside chatbot action
                const modalBtn = botMsgDiv.querySelector('.open-modal-btn');
                if (modalBtn) {
                    modalBtn.addEventListener('click', () => {
                        chatbotWindow.style.display = 'none'; // Close bot
                        openModal();
                    });
                }
                
                chatbotMessages.scrollTop = chatbotMessages.scrollHeight;
                
                // Enable chips back
                allChips.forEach(btn => btn.disabled = false);
            }, 1200);
        });
    }

});
