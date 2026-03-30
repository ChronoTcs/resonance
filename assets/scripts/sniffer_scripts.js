/**
 * Resonance On-Demand Video Extractor (Iframe Diving Edition)
 * Returns a JSON String containing an array of categorized objects:
 * [ { "type": "VIDEO", "url": "...", "title": "...", "site": "..." }, { "type": "IFRAME", "url": "..." } ]
 */
(function() {
    const findings = [];
    const addedUrls = new Set();
    const manifestExtensions = ['.m3u8', '.mp4', '.ts', '.mpd', '.m4s'];
    const pageTitle = document.title || 'Unknown Page';
    const siteName = document.querySelector('meta[property="og:site_name"]')?.content || '';

    function isVideoUrl(url) {
        if (!url || typeof url !== 'string') return false;
        const cleanUrl = url.split('?')[0].split('#')[0].toLowerCase();
        return manifestExtensions.some(ext => cleanUrl.endsWith(ext));
    }

    function addFinding(type, url, customTitle = null) {
        if (!url || typeof url !== 'string' || addedUrls.has(url)) return;
        
        // If it's tagged as VIDEO but doesn't look like one, downgrade to IFRAME or ignore
        if (type === 'VIDEO' && !isVideoUrl(url)) {
            // Check if it's an iframe-like URL that we might have caught accidentally
            if (url.includes('embed') || url.includes('player') || url.includes('iframe')) {
                type = 'IFRAME';
            } else {
                return; // Ignore false positive
            }
        }

        let title = customTitle;
        if (!title) {
            if (type === 'VIDEO') {
                const fileName = url.split('/').pop().split('?')[0];
                title = fileName.length > 5 ? fileName : pageTitle;
            } else {
                try {
                    title = `Host: ${new URL(url).hostname}`;
                } catch(e) {
                    title = 'Player Host (Tap to Dive)';
                }
            }
        }

        addedUrls.add(url);
        findings.push({ 
            type: type, 
            url: url, 
            title: title,
            site: siteName 
        });
    }

    // 1. Crawler: <video> elements
    try {
        const videos = document.querySelectorAll('video');
        videos.forEach(v => {
            if (v.src && !v.src.startsWith('blob:')) {
                addFinding('VIDEO', v.src);
            }
            v.querySelectorAll('source').forEach(s => {
                if (s.src) addFinding('VIDEO', s.src);
            });
        });
    } catch (e) {}

    // 2. Crawler: <iframe> elements (Diving Targets)
    try {
        const iframes = document.querySelectorAll('iframe');
        iframes.forEach(i => {
            if (!i.src) return;
            const src = i.src.toLowerCase();
            const isLikelyPlayer = src.includes('embed') || 
                                 src.includes('player') || 
                                 src.includes('video') ||
                                 src.includes('vview') ||
                                 i.offsetWidth > 300;

            if (isLikelyPlayer && !src.includes('ads') && !src.includes('google')) {
                addFinding('IFRAME', i.src);
            }
        });
    } catch (e) {}

    // 3. Variable Global: jwplayer
    try {
        if (typeof jwplayer === 'function') {
            const playlist = jwplayer().getPlaylist();
            if (playlist && playlist[0] && playlist[0].file) {
                addFinding('VIDEO', playlist[0].file);
            }
        }
    } catch (e) {}

    // 4. Variable Global: videojs
    try {
        if (window.videojs) {
            const players = window.videojs.players;
            for (let id in players) {
                const src = players[id].src();
                if (src) addFinding('VIDEO', src);
            }
        }
    } catch (e) {}

    // 5. Script Regex: Search for manifest patterns in inline scripts
    try {
        const scripts = document.querySelectorAll('script');
        scripts.forEach(s => {
            const content = s.textContent;
            if (!content) return;
            const matches = content.match(/["'](https?:\/\/[^"']+\.(m3u8|mp4|mpd)[^"']*)["']/g);
            if (matches) {
                matches.forEach(m => {
                    const url = m.replace(/["']/g, '');
                    if (!url.includes('google-analytics') && !url.includes('ads')) {
                        addFinding('VIDEO', url);
                    }
                });
            }
        });
    } catch (e) {}

    return JSON.stringify(findings);
})();
