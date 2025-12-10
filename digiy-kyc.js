document.addEventListener('DOMContentLoaded', () => {
  const form = document.getElementById('digiy-loc-kyc-form');
  const statusEl = document.getElementById('digiy-loc-kyc-status');

  if (!form || !statusEl) return;

  form.addEventListener('submit', async (e) => {
    e.preventDefault();

    statusEl.style.color = '#888';
    statusEl.textContent = '⏳ Envoi de ta demande à DIGIY…';

    const formData = new FormData(form);

    const payload = {
      user_id: 'LOC_OWNER_' + Date.now(),     // plus tard: vrai ID DIGIY
      job_type: 1,                            // placeholder pour Smile
      source_module: 'DIGIY_LOC',
      full_name: formData.get('fullName'),
      phone: formData.get('phone'),
      email: formData.get('email'),
      property_type: formData.get('propertyType')
    };

    try {
      const res = await fetch('https://kyc.digiylyfe.com/kyc/verify', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(payload)
      });

      const data = await res.json().catch(() => ({}));

      if (!res.ok || !data.ok) {
        console.error('DIGIY KYC error:', data);
        statusEl.style.color = '#f97373';
        statusEl.textContent = '❌ Erreur côté KYC DIGIY. Réessaie plus tard ou contacte-nous sur WhatsApp.';
        return;
      }

      statusEl.style.color = '#22c55e';
      statusEl.textContent = '✅ C’est reçu ! Ton dossier propriétaire est transmis à DIGIY. On revient vers toi pour finaliser.';

      // form.reset(); // si tu veux vider après envoi
    } catch (err) {
      console.error('DIGIY KYC fetch error:', err);
      statusEl.style.color = '#f97373';
      statusEl.textContent = '❌ Impossible de joindre DIGIY (connexion). Vérifie ton réseau et réessaie.';
    }
  });
});
