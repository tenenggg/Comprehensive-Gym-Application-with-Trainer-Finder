const express = require('express');
const cors = require('cors');
const stripe = require('stripe')('sk_test_51QjJmZC8SPAz3zkOskmznaDSA8ei7jH8Jh4lJuUsDOGqjyNI6TRCtc6dWpTzohPtje8dTbo2ahWUG4h8033tajFZ005Nt39oZP');

const app = express();
const port = 3000;

// Enable CORS
app.use(cors());
app.use(express.json());

// Test endpoint
app.get('/', (req, res) => {
  res.json({ status: 'Server is running' });
});

// Create payment intent endpoint
app.post('/create-payment-intent', async (req, res) => {
  try {
    const { amount, currency } = req.body;
    console.log('Creating payment intent:', { amount, currency });

    const paymentIntent = await stripe.paymentIntents.create({
      amount: parseInt(amount),
      currency: currency.toLowerCase(),
      payment_method_types: ['card'],
    });

    console.log('Payment intent created:', paymentIntent.id);
    res.json({
      clientSecret: paymentIntent.client_secret,
      id: paymentIntent.id
    });
  } catch (error) {
    console.error('Error:', error);
    res.status(500).json({ error: error.message });
  }
});

app.listen(port, '0.0.0.0', () => {
  console.log(`Server running on http://0.0.0.0:${port}`);
}); 