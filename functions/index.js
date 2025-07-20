/**
 * SOI App Short Link Service
 * Firebase Cloud Functions for URL shortening and redirect
 */

const {setGlobalOptions} = require("firebase-functions");
const {onRequest, onCall} = require("firebase-functions/v2/https");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const logger = require("firebase-functions/logger");
const {generateInviteImage} = require("./lib/image-generator");

// Initialize Firebase Admin
initializeApp();
const db = getFirestore();

setGlobalOptions({maxInstances: 10});

/**
 * Generate random short code
 * @param {number} length - The length of the short code
 * @return {string} Random short code
 */
function generateShortCode(length = 8) {
  const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmno" +
    "pqrstuvwxyz0123456789";
  let result = "";
  for (let i = 0; i < length; i++) {
    result += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return result;
}

// Create short link - callable function for app
exports.createShortLink = onCall(async (request) => {
  try {
    const {
      longUrl, userId, userDisplayName, generateCustomImage,
    } = request.data;

    if (!longUrl || !userId) {
      throw new Error("Missing required fields: longUrl, userId");
    }

    // Generate unique short code
    let shortCode;
    let isUnique = false;
    let attempts = 0;

    while (!isUnique && attempts < 10) {
      shortCode = generateShortCode();
      const existingDoc = await db.collection("short_links")
          .doc(shortCode).get();
      if (!existingDoc.exists) {
        isUnique = true;
      }
      attempts++;
    }

    if (!isUnique) {
      throw new Error("Failed to generate unique short code");
    }

    // Generate custom image if requested
    let customImageUrl = null;
    if (generateCustomImage) {
      try {
        const authToken = request.auth && request.auth.token ?
          request.auth.token : {};
        customImageUrl = await generateInviteImage({
          userId,
          displayName: userDisplayName,
          photoURL: authToken.picture || null,
        });
        logger.info(`Generated custom image: ${customImageUrl}`);
      } catch (imageError) {
        logger.warn("Failed to generate custom image:", imageError);
        // Continue without custom image
      }
    }

    // Save to Firestore
    const linkData = {
      shortCode,
      longUrl,
      createdBy: userId,
      createdByName: userDisplayName || "Unknown",
      createdAt: new Date(),
      clicks: 0,
      isActive: true,
      customImageUrl,
    };

    await db.collection("short_links").doc(shortCode).set(linkData);

    logger.info(`Short link created: ${shortCode} -> ${longUrl}`, {userId});

    return {
      success: true,
      shortCode,
      shortUrl: `https://soi-sns.web.app/links/${shortCode}`,
      longUrl,
      customImageUrl,
    };
  } catch (error) {
    logger.error("Error creating short link:", error);
    throw new Error(`Failed to create short link: ${error.message}`);
  }
});

// Generate invite image - callable function for testing and preview
exports.generateInviteImage = onCall(async (request) => {
  try {
    const {userId, userDisplayName, customMessage} = request.data;

    if (!userId) {
      throw new Error("Missing required field: userId");
    }

    const authToken = request.auth && request.auth.token ?
      request.auth.token : {};
    const imageUrl = await generateInviteImage({
      userId,
      displayName: userDisplayName,
      photoURL: authToken.picture || null,
    }, customMessage);

    logger.info(`Generated invite image: ${imageUrl}`, {userId});

    return {
      success: true,
      imageUrl,
    };
  } catch (error) {
    logger.error("Error generating invite image:", error);
    throw new Error(`Failed to generate invite image: ${error.message}`);
  }
});

// Main redirect handler for all incoming requests
exports.app = onRequest(async (req, res) => {
  try {
    const path = req.path;
    const method = req.method;

    logger.info(`Request: ${method} ${path}`, {
      userAgent: req.get("user-agent"),
    });

    // Handle short link redirects: /links/{shortCode}
    if (path.startsWith("/links/")) {
      const shortCode = path.split("/links/")[1];

      if (!shortCode) {
        return res.status(400).send("Invalid short link format");
      }

      // Get link data from Firestore
      const linkDoc = await db.collection("short_links").doc(shortCode).get();

      if (!linkDoc.exists) {
        return res.status(404).send(`
          <!DOCTYPE html>
          <html>
          <head>
            <title>Link Not Found - SOI</title>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
          </head>
          <body>
            <h1>Link Not Found</h1>
            <p>This short link does not exist or has expired.</p>
            <a href="https://soi-sns.web.app">Go to SOI</a>
          </body>
          </html>
        `);
      }

      const linkData = linkDoc.data();

      if (!linkData.isActive) {
        return res.status(410).send("This link has been deactivated");
      }

      // Update click count
      await db.collection("short_links").doc(shortCode).update({
        clicks: (linkData.clicks || 0) + 1,
        lastAccessed: new Date(),
      });

      // Log the redirect
      logger.info(`Redirecting ${shortCode} to ${linkData.longUrl}`, {
        clicks: linkData.clicks + 1,
        createdBy: linkData.createdBy,
      });

      // Redirect to long URL
      return res.redirect(302, linkData.longUrl);
    }

    // Handle invite page: /invites/{userId}
    if (path.startsWith("/invites/")) {
      const userId = path.split("/invites/")[1];
      const query = req.query;

      // Extract social media parameters
      const socialTitle = query.social_title || "Join SOI";
      const socialDesc = query.social_desc || "Connect with friends on SOI";
      const socialImg = query.social_img || "https://soi-sns.web.app/SOI_logo.png";
      const lang = query.lang || "ko";
      const platform = query.type || "default";

      // Generate invite page HTML with meta tags for rich preview
      const inviteHTML = `
        <!DOCTYPE html>
        <html lang="${lang}">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>${socialTitle}</title>
          
          <!-- Open Graph meta tags for rich previews -->
          <meta property="og:title" content="${socialTitle}">
          <meta property="og:description" content="${socialDesc}">
          <meta property="og:image" content="${socialImg}">
          <meta property="og:type" content="website">
          <meta property="og:url" 
            content="https://soi-sns.web.app${path}">
          
          <!-- Twitter Card meta tags -->
          <meta name="twitter:card" content="summary_large_image">
          <meta name="twitter:title" content="${socialTitle}">
          <meta name="twitter:description" content="${socialDesc}">
          <meta name="twitter:image" content="${socialImg}">
          
          <!-- Additional meta tags -->
          <meta name="description" content="${socialDesc}">
          
          <style>
            body {
              font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 
                Roboto, sans-serif;
              margin: 0;
              padding: 20px;
              background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
              min-height: 100vh;
              display: flex;
              align-items: center;
              justify-content: center;
            }
            .container {
              background: white;
              border-radius: 20px;
              padding: 40px;
              text-align: center;
              box-shadow: 0 20px 40px rgba(0,0,0,0.1);
              max-width: 400px;
              width: 100%;
            }
            .logo {
              width: 80px;
              height: 80px;
              margin: 0 auto 20px;
              background: #667eea;
              border-radius: 50%;
              display: flex;
              align-items: center;
              justify-content: center;
              color: white;
              font-size: 24px;
              font-weight: bold;
            }
            h1 { color: #333; margin-bottom: 10px; }
            p { color: #666; margin-bottom: 30px; }
            .download-button {
              display: inline-block;
              background: #667eea;
              color: white;
              padding: 15px 30px;
              border-radius: 10px;
              text-decoration: none;
              font-weight: bold;
              margin: 10px;
              transition: transform 0.2s;
            }
            .download-button:hover {
              transform: translateY(-2px);
            }
            .platform-info {
              margin-top: 20px;
              font-size: 12px;
              color: #999;
            }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="logo">SOI</div>
            <h1>${socialTitle}</h1>
            <p>${socialDesc}</p>
            
            <a href="soi://invite/${userId}" class="download-button" onclick="setTimeout(() => window.location.href='https://apps.apple.com/app/soi', 2000)">
              Open SOI App
            </a>
            
            <div class="platform-info">
              Platform: ${platform} | User: ${userId}
            </div>
          </div>
          
          <script>
            // Auto-redirect logic similar to existing invite page
            const userAgent = navigator.userAgent;
            const isAndroid = /Android/i.test(userAgent);
            const isIOS = /iPhone|iPad|iPod/i.test(userAgent);
            
            if (isAndroid) {
              setTimeout(() => {
                window.location.href = 'https://play.google.com/store/apps/details?id=com.soi.app';
              }, 3000);
            } else if (isIOS) {
              setTimeout(() => {
                window.location.href = 'https://apps.apple.com/app/soi';
              }, 3000);
            }
          </script>
        </body>
        </html>
      `;

      return res.send(inviteHTML);
    }

    // Default: serve existing static content
    return res.redirect("https://soi-sns.web.app");
  } catch (error) {
    logger.error("Request handler error:", error);
    return res.status(500).send("Internal server error");
  }
});

