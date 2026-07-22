-- Migration 099: Seed ai_prompts row for wallet / bill_scan image parsing.
-- Scans a spending/earning bill (shop receipt, restaurant bill, fuel bill,
-- medical bill, utility bill, invoice, payslip, etc.) into line items that
-- can be added as Wallet transactions. Mirrors the pantry/bill_scan guard
-- pattern (migration 098) — classifies the bill first so an unrelated photo
-- doesn't get force-parsed into fake transactions.

INSERT INTO ai_prompts (feature, sub_feature, input_type, version, is_active, notes, prompt, schema_hint)
VALUES (
  'wallet',
  'bill_scan',
  'image',
  1,
  true,
  'Parse a spending/earning bill image into structured transaction line items',
  $PROMPT$
You are a financial bill/receipt parser for an Indian household expense tracking app.
Examine this bill, receipt, invoice, or payslip carefully.

First, decide whether this is a BILL/RECEIPT RELATED TO SPENDING OR EARNING
MONEY — a shop receipt, restaurant/hotel bill, fuel bill, medical bill,
utility bill, invoice, payslip/salary slip, or similar. If the image is NOT
one of these (e.g. a random photo, a to-do list, a grocery list without
prices, an unrelated document), return:
{
  "is_financial_bill": false,
  "bill_type_guess": "unknown",
  "merchant": null,
  "items": [],
  "total_amount": null,
  "confidence": 0.9
}
(set "bill_type_guess" to whatever it actually looks like if you can tell,
e.g. "todo_list", "unrelated_photo").

Only if it IS a financial bill, extract EVERY distinct line item (product,
service, or fee) listed. For each item return:
- title: concise item/service name (max 5 words)
- amount: item amount in {{currency}} (the line total, not unit price)
- category: one of: Food, Transport, Shopping, Health, Education,
  Entertainment, Utilities, Rent, Salary, Freelance, Investment, Groceries,
  Medical, Travel, Fuel, Clothing, Subscription, Festival, Functions,
  Cash Withdrawal, Other
- type: "expense" or "income" (income only for a payslip/salary credit/refund
  document — almost every bill/receipt is "expense")
- confidence: float 0.0–1.0 how confident you are in this extraction

Return ONLY valid JSON — no markdown, no explanation:
{
  "is_financial_bill": true,
  "merchant": "Store or business name if visible, else null",
  "items": [
    {
      "title": "Chicken Biryani",
      "amount": 220.00,
      "category": "Food",
      "type": "expense",
      "confidence": 0.92
    }
  ],
  "total_amount": 1250.00,
  "confidence": 0.90
}

Rules:
- If an item's amount isn't clearly visible, skip that item rather than guessing
- Skip taxes, delivery charges, discounts, and the store name itself as line items
  (they are not purchasable items) — but DO factor them into total_amount if shown
- If the bill has only one combined amount and no itemization, return a single
  item using the bill's overall title/merchant as the item title
- Currency is {{currency}}
$PROMPT$,
  '{"type":"object","properties":{"is_financial_bill":{"type":"boolean"},"bill_type_guess":{"type":"string"},"merchant":{"type":"string"},"items":{"type":"array"},"total_amount":{"type":"number"},"confidence":{"type":"number"}}}'
)
ON CONFLICT (feature, sub_feature, input_type, version) DO UPDATE
  SET prompt      = EXCLUDED.prompt,
      is_active   = true,
      schema_hint = EXCLUDED.schema_hint;
