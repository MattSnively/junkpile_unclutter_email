class JunkpileApp {
    constructor() {
        this.emails = [];
        this.currentIndex = 0;
        this.unsubscribeCount = 0;
        this.decisions = [];

        this.isDragging = false;
        this.startX = 0;
        this.currentX = 0;

        this.initElements();
        this.initEventListeners();
    }

    initElements() {
        this.connectSection = document.getElementById('connectSection');
        this.swipeSection = document.getElementById('swipeSection');
        this.completeSection = document.getElementById('completeSection');

        this.connectBtn = document.getElementById('connectBtn');
        this.restartBtn = document.getElementById('restartBtn');

        this.card = document.getElementById('emailCard');
        this.cardSender = document.getElementById('cardSender');
        this.cardSubject = document.getElementById('cardSubject');
        this.cardBody = document.getElementById('cardBody');

        this.unsubscribeCountEl = document.getElementById('unsubscribeCount');
        this.remainingCountEl = document.getElementById('remainingCount');
        this.summaryEl = document.getElementById('summary');

        this.unsubscribePile = document.getElementById('unsubscribePile');
        this.keepPile = document.getElementById('keepPile');
    }

    initEventListeners() {
        this.connectBtn.addEventListener('click', () => this.connectEmail());
        this.restartBtn.addEventListener('click', () => this.restart());

        // Mouse events
        this.card.addEventListener('mousedown', (e) => this.startDrag(e));
        document.addEventListener('mousemove', (e) => this.drag(e));
        document.addEventListener('mouseup', () => this.endDrag());

        // Touch events
        this.card.addEventListener('touchstart', (e) => this.startDrag(e));
        document.addEventListener('touchmove', (e) => this.drag(e));
        document.addEventListener('touchend', () => this.endDrag());

        // Keyboard support
        document.addEventListener('keydown', (e) => {
            if (this.swipeSection.classList.contains('hidden')) return;

            if (e.key === 'ArrowLeft') {
                this.makeDecision('unsubscribe');
            } else if (e.key === 'ArrowRight') {
                this.makeDecision('keep');
            }
        });
    }

    async connectEmail() {
        try {
            // First, check if we need to authenticate
            const authResponse = await fetch('/api/auth/url');
            const authData = await authResponse.json();

            if (authData.needsSetup) {
                alert('Gmail API is not configured yet. Please set up your .env file with Gmail OAuth credentials. See the README for instructions.');
                return;
            }

            if (authData.authUrl) {
                // Redirect to Google OAuth
                window.location.href = authData.authUrl;
                return;
            }

            // If already authenticated, try to fetch emails
            const response = await fetch('/api/emails');
            const data = await response.json();

            if (data.needsAuth) {
                // Need to authenticate first
                const urlResponse = await fetch('/api/auth/url');
                const urlData = await urlResponse.json();
                if (urlData.authUrl) {
                    window.location.href = urlData.authUrl;
                }
            } else if (data.success) {
                this.emails = data.emails;
                if (this.emails.length === 0) {
                    alert('No emails with unsubscribe links found in your inbox!');
                    return;
                }
                this.startSwiping();
            }
        } catch (error) {
            console.error('Error connecting email:', error);
            alert('Error connecting to email. Please try again.');
        }
    }

    checkAuthStatus() {
        const urlParams = new URLSearchParams(window.location.search);
        const authStatus = urlParams.get('auth');

        if (authStatus === 'success') {
            // Remove the query parameter
            window.history.replaceState({}, document.title, '/');
            // Fetch emails
            this.fetchEmailsAfterAuth();
        } else if (authStatus === 'error') {
            alert('Authentication failed. Please try again.');
            window.history.replaceState({}, document.title, '/');
        }
    }

    async fetchEmailsAfterAuth() {
        try {
            const response = await fetch('/api/emails');
            const data = await response.json();

            if (data.success) {
                this.emails = data.emails;
                if (this.emails.length === 0) {
                    alert('No emails with unsubscribe links found in your inbox!');
                    return;
                }
                this.startSwiping();
            }
        } catch (error) {
            console.error('Error fetching emails:', error);
            alert('Error fetching emails. Please try again.');
        }
    }

    startSwiping() {
        this.connectSection.classList.add('hidden');
        this.swipeSection.classList.remove('hidden');
        this.updateStats();
        this.showCurrentEmail();
    }

    showCurrentEmail() {
        if (this.currentIndex >= this.emails.length) {
            this.showComplete();
            return;
        }

        const email = this.emails[this.currentIndex];
        this.cardSender.textContent = email.sender;
        this.cardSubject.textContent = email.subject;

        // Render email body HTML in an iframe for proper isolation
        if (email.htmlBody) {
            const iframe = document.createElement('iframe');
            iframe.srcdoc = email.htmlBody;
            iframe.sandbox = 'allow-same-origin';
            this.cardBody.innerHTML = '';
            this.cardBody.appendChild(iframe);
        } else {
            this.cardBody.innerHTML = `<div style="padding: 20px; color: #666;">${email.preview || 'No preview available'}</div>`;
        }

        this.card.style.transform = 'translate(0, 0) rotate(0deg)';
        this.card.style.opacity = '1';
    }

    addEnvelope(pile) {
        const envelope = document.createElement('div');
        envelope.className = 'envelope';
        pile.appendChild(envelope);
    }

    startDrag(e) {
        this.isDragging = true;
        this.startX = e.type.includes('mouse') ? e.clientX : e.touches[0].clientX;
        this.card.style.transition = 'none';
    }

    drag(e) {
        if (!this.isDragging) return;

        e.preventDefault();
        this.currentX = e.type.includes('mouse') ? e.clientX : e.touches[0].clientX;
        const deltaX = this.currentX - this.startX;
        const rotation = deltaX / 20;

        this.card.style.transform = `translate(${deltaX}px, 0) rotate(${rotation}deg)`;

        // Visual feedback
        if (deltaX < -50) {
            this.card.classList.add('swiping-left');
            this.card.classList.remove('swiping-right');
        } else if (deltaX > 50) {
            this.card.classList.add('swiping-right');
            this.card.classList.remove('swiping-left');
        } else {
            this.card.classList.remove('swiping-left', 'swiping-right');
        }
    }

    endDrag() {
        if (!this.isDragging) return;

        this.isDragging = false;
        const deltaX = this.currentX - this.startX;

        this.card.style.transition = 'transform 0.3s ease, opacity 0.3s ease';

        if (deltaX < -100) {
            this.swipeCard('unsubscribe');
        } else if (deltaX > 100) {
            this.swipeCard('keep');
        } else {
            this.card.style.transform = 'translate(0, 0) rotate(0deg)';
            this.card.classList.remove('swiping-left', 'swiping-right');
        }
    }

    swipeCard(decision) {
        const direction = decision === 'unsubscribe' ? -1 : 1;
        this.card.style.transform = `translate(${direction * 600}px, 0) rotate(${direction * 30}deg)`;
        this.card.style.opacity = '0';

        setTimeout(() => {
            this.makeDecision(decision);
            this.card.classList.remove('swiping-left', 'swiping-right');
        }, 300);
    }

    async makeDecision(decision) {
        const email = this.emails[this.currentIndex];

        this.decisions.push({
            email: email,
            decision: decision,
            timestamp: new Date().toISOString()
        });

        if (decision === 'unsubscribe') {
            this.unsubscribeCount++;
            this.addEnvelope(this.unsubscribePile);
        } else {
            this.addEnvelope(this.keepPile);
        }

        // Send decision to server
        try {
            await fetch('/api/decision', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    emailId: email.id,
                    decision: decision
                })
            });
        } catch (error) {
            console.error('Error saving decision:', error);
        }

        this.currentIndex++;
        this.updateStats();
        this.showCurrentEmail();
    }

    updateStats() {
        this.unsubscribeCountEl.textContent = this.unsubscribeCount;
        this.remainingCountEl.textContent = this.emails.length - this.currentIndex;
    }

    showComplete() {
        this.swipeSection.classList.add('hidden');
        this.completeSection.classList.remove('hidden');

        const keptCount = this.decisions.length - this.unsubscribeCount;
        this.summaryEl.innerHTML = `
            <strong>Unsubscribed:</strong> ${this.unsubscribeCount}<br>
            <strong>Kept:</strong> ${keptCount}<br>
            <strong>Total processed:</strong> ${this.decisions.length}
        `;
    }

    restart() {
        this.currentIndex = 0;
        this.unsubscribeCount = 0;
        this.decisions = [];

        this.completeSection.classList.add('hidden');
        this.connectSection.classList.remove('hidden');
    }
}

// Initialize app when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    const app = new JunkpileApp();
    app.checkAuthStatus();
});
