require('dotenv').config();
const express = require('express');
const cors = require('cors');
const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);

const app = express();
const port = process.env.PORT || 8080;

app.use(cors());
app.use(express.json());

app.post('/create-payment-intent', async (req, res) => {
  try {
    const { amount } = req.body;

    const paymentIntent = await stripe.paymentIntents.create({
      amount: amount,
      currency: 'myr',
      capture_method: 'manual',
      automatic_payment_methods: {
        enabled: true,
      },
    });

    res.json({
      clientSecret: paymentIntent.client_secret,
      paymentIntentId: paymentIntent.id,
    });
  } catch (e) {
    console.error('Error creating payment intent:', e);
    res.status(500).json({ error: e.message });
  }
});

app.post('/capture-payment-intent', async (req, res) => {
  try {
    const { paymentIntentId } = req.body;
    const paymentIntent = await stripe.paymentIntents.capture(paymentIntentId);
    res.json({ success: true, paymentIntent });
  } catch (e) {
    console.error('Error capturing payment intent:', e);
    res.status(500).json({ error: e.message });
  }
});

app.post('/cancel-payment-intent', async (req, res) => {
  try {
    const { paymentIntentId } = req.body;
    const paymentIntent = await stripe.paymentIntents.retrieve(paymentIntentId);
    if (paymentIntent.status === 'requires_capture') {
      // Not captured yet, just cancel
      await stripe.paymentIntents.cancel(paymentIntentId);
      res.json({ success: true, cancelled: true });
    } else if (paymentIntent.status === 'succeeded') {
      // Already captured, refund
      await stripe.refunds.create({ payment_intent: paymentIntentId });
      res.json({ success: true, refunded: true });
    } else {
      res.json({ success: false, message: 'Nothing to cancel or refund.' });
    }
  } catch (e) {
    console.error('Error cancelling/refunding payment intent:', e);
    res.status(500).json({ error: e.message });
  }
});

app.post('/refund-payment', async (req, res) => {
  try {
    const { paymentIntentId, reason } = req.body;

    if (!paymentIntentId) {
      return res.status(400).json({ error: 'Payment Intent ID is required' });
    }
    
    // Retrieve the payment intent to check its status
    const paymentIntent = await stripe.paymentIntents.retrieve(paymentIntentId);
    
    // If the payment was successfully captured, refund it.
    if (paymentIntent.status === 'succeeded') {
      const refund = await stripe.refunds.create({
        payment_intent: paymentIntentId,
        reason: reason || 'requested_by_customer',
      });
      
      return res.json({
        success: true,
        refundId: refund.id,
        status: refund.status,
      });
    } 
    // If the payment was authorized but not captured, simply cancel it.
    else if (paymentIntent.status === 'requires_capture') {
      const cancelledIntent = await stripe.paymentIntents.cancel(paymentIntentId);
      return res.json({
        success: true,
        status: cancelledIntent.status, // will be 'canceled'
      });
    } 
    // For any other status (e.g., 'canceled', 'processing'), do nothing.
    else {
      return res.status(400).json({
        success: false,
        status: paymentIntent.status,
        message: `Payment cannot be refunded or canceled in its current state: ${paymentIntent.status}`,
      });
    }
  } catch (e) {
    console.error('--- ERROR IN /refund-payment ---');
    console.error(e);
    // Ensure a JSON response is always sent on error
    return res.status(500).json({ error: e.message });
  }
});

app.listen(port, '0.0.0.0', () => {
  console.log(`Server running on port ${port}`);
}); 