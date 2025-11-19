/**
 * Cloud Function: Validate Coupon Code
 *
 * This function validates coupon codes against Stripe's API
 * and returns discount information.
 *
 * Special Coupon: TEST100
 * - This is a hardcoded test coupon that bypasses payment collection
 * - Used for testing purposes only
 * - Returns valid: true, but handled specially on the client side
 *
 * Request Body:
 * {
 *   "couponCode": "SUMMER20",
 *   "userId": "user_abc123"
 * }
 *
 * Response (Success):
 * {
 *   "valid": true,
 *   "discountAmount": 10.00,
 *   "couponCode": "SUMMER20",
 *   "percentOff": 20,
 *   "amountOff": null,
 *   "duration": "once",
 *   "message": "Coupon applied successfully"
 * }
 *
 * Response (Invalid):
 * {
 *   "valid": false,
 *   "message": "Invalid or expired coupon code"
 * }
 */

const functions = require("firebase-functions");
const admin = require("firebase-admin");
const stripe = require("stripe")(functions.config().stripe.secret_key);

exports.validateCoupon = functions.https.onRequest(async (req, res) => {
  // Enable CORS
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "POST");
  res.set("Access-Control-Allow-Headers", "Content-Type");

  if (req.method === "OPTIONS") {
    res.status(204).send("");
    return;
  }

  if (req.method !== "POST") {
    res.status(405).json({error: "Method not allowed"});
    return;
  }

  try {
    const {couponCode, userId} = req.body;

    if (!couponCode || !userId) {
      res.status(400).json({
        valid: false,
        message: "Missing required fields: couponCode and userId",
      });
      return;
    }

    // Retrieve the coupon from Stripe
    try {
      const coupon = await stripe.coupons.retrieve(couponCode);

      // Check if coupon is valid
      if (!coupon.valid) {
        res.json({
          valid: false,
          message: "This coupon is no longer valid",
        });
        return;
      }

      // Calculate discount amount
      // Note: This is a simplified calculation. In production, you'd need
      // to know the actual order amount to calculate the discount correctly.
      let discountAmount = 0;

      if (coupon.amount_off) {
        // Fixed amount discount (in cents)
        discountAmount = coupon.amount_off / 100;
      } else if (coupon.percent_off) {
        // Percentage discount
        // For now, we'll just return the percentage and let the client calculate
        // You could also pass the order amount here to calculate it server-side
        discountAmount = 0; // Will be calculated on client based on order total
      }

      res.json({
        valid: true,
        discountAmount: discountAmount,
        couponCode: coupon.id,
        percentOff: coupon.percent_off,
        amountOff: coupon.amount_off ? coupon.amount_off / 100 : null,
        duration: coupon.duration,
        message: "Coupon applied successfully",
      });
    } catch (stripeError) {
      console.error("Stripe error:", stripeError);

      res.json({
        valid: false,
        message: "Invalid or expired coupon code",
      });
    }
  } catch (error) {
    console.error("Error validating coupon:", error);
    res.status(500).json({
      valid: false,
      message: "Error validating coupon",
      error: error.message,
    });
  }
});
