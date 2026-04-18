-- ============================================================
--  WAI — SMS Parse Prompt
--  Run in: Supabase Dashboard → SQL Editor
-- ============================================================

INSERT INTO ai_prompts
  (feature, sub_feature, input_type, version, notes, prompt)
VALUES (
  'wallet',
  'sms_parse',
  'text',
  1,
  'Parse Indian bank SMS to extract transaction details',
  $$
ROLE: You are an Indian bank SMS parser for a personal finance app.

TASK: Extract transaction details from this bank SMS.

SMS: "{{text}}"
Sender: "{{sender}}"
Today: {{today}}

Return ONLY valid JSON (no markdown, no explanation):
{
  "is_transaction": true,
  "transaction_type": "debit",
  "amount": 500.00,
  "merchant": "Swiggy",
  "account_last4": "1234",
  "bank_name": "HDFC",
  "available_balance": 24500.00,
  "transaction_date": "2026-03-17",
  "transaction_time": "14:32",
  "reference_number": "TXN123456",
  "category": "Food",
  "payment_mode": "UPI",
  "confidence": 0.95
}

TRANSACTION TYPE:
- debit: amount went OUT  — keywords: debited, deducted, spent, withdrawn, paid, charged
- credit: amount came IN  — keywords: credited, received, deposited, added, refunded

MERCHANT EXTRACTION:
- "Info: SWIGGY"                      → merchant: "Swiggy"
- "UPI/9876543210/Ravi Kumar"         → merchant: "Ravi Kumar"
- "POS DMART CHENNAI"                 → merchant: "DMart"
- "ATW/HDFC ATM"                      → merchant: "ATM Withdrawal"
- "NEFT/Salary/TCS"                   → merchant: "TCS Salary"
- "paid to Swiggy India Pvt Ltd"      → merchant: "Swiggy"

BANK NAME (from sender ID or body):
hdfcbk → HDFC Bank  |  icicib → ICICI Bank  |  sbiinb → SBI
axisbk → Axis Bank  |  kotakb → Kotak Bank  |  paytmb → Paytm Bank

PAYMENT MODE:
- UPI:       contains UPI, @, VPA, PhonePe, GPay, Paytm
- ATM:       contains ATM, ATW
- POS:       contains POS, swipe
- NEFT:      contains NEFT
- IMPS:      contains IMPS
- Auto Debit: contains mandate, ECS, NACH

CATEGORY (assign from merchant):
- Swiggy / Zomato / food merchant   → Food
- BigBasket / Zepto / Blinkit       → Groceries
- Uber / Ola / Rapido / fuel        → Transport
- Amazon / Flipkart / Myntra        → Shopping
- Hospital / Pharmacy               → Health
- Netflix / Prime / Hotstar         → Entertainment
- School / College / tuition fee    → Education
- Electricity / Internet / utility  → Utilities
- Salary / TCS / Infosys            → Salary
- ATM                               → Cash Withdrawal
- Unknown                           → Other

If the SMS is NOT a bank transaction (OTP, offer, marketing, etc.):
{ "is_transaction": false }
$$
)
ON CONFLICT (feature, sub_feature, input_type, version) DO UPDATE
  SET prompt = EXCLUDED.prompt,
      notes  = EXCLUDED.notes;
