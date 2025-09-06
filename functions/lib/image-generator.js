const {createCanvas, loadImage} = require("canvas");
const {getStorage} = require("firebase-admin/storage");
const {v4: uuidv4} = require("uuid");

/**
 * Generate personalized invite image similar to Locket Camera
 * @param {Object} userInfo - User information
 * @param {string} userInfo.displayName - User's display name
 * @param {string} userInfo.photoURL - User's profile photo URL
 * @param {string} userInfo.userId - User's ID
 * @param {string} customMessage - Custom invitation message
 * @return {Promise<string>} Public URL of generated image
 */
async function generateInviteImage(userInfo, customMessage = null) {
  try {
    // Canvas dimensions (optimized for social media)
    const width = 1200;
    const height = 630;
    const canvas = createCanvas(width, height);
    const ctx = canvas.getContext("2d");

    // SOI brand colors
    const primaryColor = "#667eea";
    const secondaryColor = "#764ba2";
    const textColor = "#ffffff";
    const accentColor = "#ffd700";

    // Create gradient background
    const gradient = ctx.createLinearGradient(0, 0, width, height);
    gradient.addColorStop(0, primaryColor);
    gradient.addColorStop(1, secondaryColor);
    ctx.fillStyle = gradient;
    ctx.fillRect(0, 0, width, height);

    // Add decorative elements (stars/sparkles like Locket)
    drawDecorations(ctx, width, height);

    // Load and draw user profile image
    let profileImage = null;
    if (userInfo.photoURL) {
      try {
        profileImage = await loadImage(userInfo.photoURL);
      } catch (error) {
        // console.log("Failed to load profile image, using default");
      }
    }

    // Draw profile section
    const profileX = width / 2;
    const profileY = 200;
    const profileSize = 120;

    if (profileImage) {
      // Draw circular profile image
      ctx.save();
      ctx.beginPath();
      ctx.arc(profileX, profileY, profileSize / 2, 0, Math.PI * 2);
      ctx.closePath();
      ctx.clip();
      ctx.drawImage(
          profileImage,
          profileX - profileSize / 2,
          profileY - profileSize / 2,
          profileSize,
          profileSize,
      );
      ctx.restore();

      // Add profile image border
      ctx.strokeStyle = textColor;
      ctx.lineWidth = 4;
      ctx.beginPath();
      ctx.arc(profileX, profileY, profileSize / 2, 0, Math.PI * 2);
      ctx.stroke();
    } else {
      // Draw default avatar
      ctx.fillStyle = "rgba(255, 255, 255, 0.3)";
      ctx.beginPath();
      ctx.arc(profileX, profileY, profileSize / 2, 0, Math.PI * 2);
      ctx.fill();

      // Add user initial
      ctx.fillStyle = textColor;
      ctx.font = "bold 48px sans-serif";
      ctx.textAlign = "center";
      ctx.textBaseline = "middle";
      const initial = userInfo.displayName ?
        userInfo.displayName.charAt(0).toUpperCase() : "U";
      ctx.fillText(initial, profileX, profileY);
    }

    // Main text content
    const userName = userInfo.displayName || "SOI 친구";
    const mainText = customMessage || `${userName}님이 SOI에 초대했어요!`;
    const subText = "SOI에서 함께 소통해보세요 💛";

    // Draw main text
    ctx.fillStyle = textColor;
    ctx.font = "bold 42px sans-serif";
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";

    // Wrap text if too long
    const maxWidth = width - 100;
    drawWrappedText(ctx, mainText, profileX, profileY + 120, maxWidth, 42);

    // Draw subtitle
    ctx.font = "400 28px sans-serif";
    ctx.fillStyle = "rgba(255, 255, 255, 0.9)";
    drawWrappedText(ctx, subText, profileX, profileY + 180, maxWidth, 28);

    // Draw SOI logo/branding
    ctx.fillStyle = accentColor;
    ctx.font = "bold 32px sans-serif";
    ctx.textAlign = "center";
    ctx.fillText("SOI", profileX, height - 80);

    // Draw "Tap to join" call-to-action
    ctx.fillStyle = "rgba(255, 255, 255, 0.8)";
    ctx.font = "400 20px sans-serif";
    ctx.fillText("Tap to join", profileX, height - 40);

    // Convert canvas to buffer
    const buffer = canvas.toBuffer("image/png");

    // Upload to Firebase Storage
    const bucket = getStorage().bucket();
    const fileName = `invite_previews/${userInfo.userId}/${Date.now()}_` +
      `${uuidv4()}.png`;
    const file = bucket.file(fileName);

    await file.save(buffer, {
      metadata: {
        contentType: "image/png",
        cacheControl: "public, max-age=3600",
      },
    });

    // Make file publicly accessible
    await file.makePublic();

    // Return public URL
    return `https://storage.googleapis.com/${bucket.name}/${fileName}`;
  } catch (error) {
    // console.error("Error generating invite image:", error);
    throw new Error(`Failed to generate invite image: ${error.message}`);
  }
}

/**
 * Draw decorative elements (stars, sparkles) on the canvas
 * @param {CanvasRenderingContext2D} ctx - Canvas context
 * @param {number} width - Canvas width
 * @param {number} height - Canvas height
 */
function drawDecorations(ctx, width, height) {
  const decorations = [
    {x: 100, y: 100, size: 8, type: "star"},
    {x: width - 150, y: 120, size: 6, type: "sparkle"},
    {x: 80, y: height - 150, size: 10, type: "star"},
    {x: width - 100, y: height - 180, size: 7, type: "sparkle"},
    {x: width - 200, y: 250, size: 5, type: "star"},
    {x: 150, y: 300, size: 9, type: "sparkle"},
  ];

  decorations.forEach((decoration) => {
    ctx.fillStyle = "rgba(255, 255, 255, 0.6)";

    if (decoration.type === "star") {
      drawStar(ctx, decoration.x, decoration.y, decoration.size);
    } else {
      drawSparkle(ctx, decoration.x, decoration.y, decoration.size);
    }
  });
}

/**
 * Draw a star shape
 * @param {CanvasRenderingContext2D} ctx - Canvas context
 * @param {number} x - X coordinate
 * @param {number} y - Y coordinate
 * @param {number} size - Star size
 */
function drawStar(ctx, x, y, size) {
  ctx.save();
  ctx.translate(x, y);
  ctx.beginPath();

  for (let i = 0; i < 5; i++) {
    ctx.lineTo(Math.cos((18 + i * 72) / 180 * Math.PI) * size,
        -Math.sin((18 + i * 72) / 180 * Math.PI) * size);
    ctx.lineTo(Math.cos((54 + i * 72) / 180 * Math.PI) * size / 2,
        -Math.sin((54 + i * 72) / 180 * Math.PI) * size / 2);
  }

  ctx.closePath();
  ctx.fill();
  ctx.restore();
}

/**
 * Draw a sparkle shape
 * @param {CanvasRenderingContext2D} ctx - Canvas context
 * @param {number} x - X coordinate
 * @param {number} y - Y coordinate
 * @param {number} size - Sparkle size
 */
function drawSparkle(ctx, x, y, size) {
  ctx.save();
  ctx.translate(x, y);
  ctx.fillRect(-size / 2, -1, size, 2);
  ctx.fillRect(-1, -size / 2, 2, size);
  ctx.restore();
}

/**
 * Draw wrapped text that fits within maxWidth
 * @param {CanvasRenderingContext2D} ctx - Canvas context
 * @param {string} text - Text to draw
 * @param {number} x - X coordinate
 * @param {number} y - Y coordinate
 * @param {number} maxWidth - Maximum width
 * @param {number} fontSize - Font size
 */
function drawWrappedText(ctx, text, x, y, maxWidth, fontSize) {
  const words = text.split(" ");
  let line = "";
  let currentY = y;
  const lineHeight = fontSize * 1.2;

  for (let i = 0; i < words.length; i++) {
    const testLine = line + words[i] + " ";
    const metrics = ctx.measureText(testLine);
    const testWidth = metrics.width;

    if (testWidth > maxWidth && i > 0) {
      ctx.fillText(line, x, currentY);
      line = words[i] + " ";
      currentY += lineHeight;
    } else {
      line = testLine;
    }
  }
  ctx.fillText(line, x, currentY);
}

module.exports = {generateInviteImage};
