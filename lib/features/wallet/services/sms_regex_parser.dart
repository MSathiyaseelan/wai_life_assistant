import 'package:wai_life_assistant/features/wallet/category_detector.dart';
import 'package:wai_life_assistant/features/wallet/models/sms_transaction.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SMSRegexParser — free, instant regex layer (Layer 1)
// Handles ~70 % of Indian bank SMS formats without any API call.
// Returns null when no pattern matches → caller falls back to AI.
// ─────────────────────────────────────────────────────────────────────────────

class SMSRegexParser {
  SMSRegexParser._();

  // ── Public entry point ────────────────────────────────────────────────────

  static SMSTransaction? tryParse(String sms) {
    final today = DateTime.now().toIso8601String().split('T')[0];

    // Try each pattern in order of specificity
    return _tryHdfcDebit(sms, today) ??
        _tryHdfcCredit(sms, today) ??
        _trySbiDebit(sms, today) ??
        _tryIciciDebit(sms, today) ??
        _tryAxisDebit(sms, today) ??
        _tryUpiPaid(sms, today) ??
        _tryUpiReceived(sms, today) ??
        _trySalaryCredit(sms, today) ??
        _tryGenericDebit(sms, today) ??
        _tryGenericCredit(sms, today);
  }

  // ── Pattern: HDFC debit ───────────────────────────────────────────────────
  // "Dear Customer, INR 500.00 debited from A/c XX1234 on 17-03-26. Info: SWIGGY."
  static SMSTransaction? _tryHdfcDebit(String sms, String today) {
    final re = RegExp(
      r'INR\s+([\d,]+\.?\d*)\s+debited\s+from\s+[Aa]/[Cc]\s+[xX]+(\d{4})'
      r'(?:.*?[Oo]n\s+([\d\-/]+))?.*?[Ii]nfo:\s*([^\.\n]+)',
      caseSensitive: false,
    );
    final m = re.firstMatch(sms);
    if (m == null) return null;
    final merchant = _clean(m.group(4));
    return SMSTransaction(
      isTransaction:   true,
      transactionType: 'debit',
      amount:          _amt(m.group(1)!),
      merchant:        merchant,
      accountLast4:    m.group(2),
      bankName:        'HDFC Bank',
      transactionDate: _date(m.group(3)) ?? today,
      category:        _cat(merchant, isIncome: false),
      paymentMode:     'UPI',
      confidence:      0.92,
    );
  }

  // ── Pattern: HDFC credit ──────────────────────────────────────────────────
  // "INR 75,000.00 credited to your A/c XX7890 on 17-03-2026 by TCS LIMITED."
  static SMSTransaction? _tryHdfcCredit(String sms, String today) {
    final re = RegExp(
      r'INR\s+([\d,]+\.?\d*)\s+credited\s+to\s+(?:your\s+)?[Aa]/[Cc]\s+[xX]+(\d{4})'
      r'(?:.*?[Oo]n\s+([\d\-/]+))?(?:.*?by\s+([A-Z][^\.\n]{1,40}))?',
      caseSensitive: false,
    );
    final m = re.firstMatch(sms);
    if (m == null) return null;
    final merchant = _clean(m.group(4));
    return SMSTransaction(
      isTransaction:   true,
      transactionType: 'credit',
      amount:          _amt(m.group(1)!),
      merchant:        merchant,
      accountLast4:    m.group(2),
      bankName:        'HDFC Bank',
      transactionDate: _date(m.group(3)) ?? today,
      category:        _cat(merchant, isIncome: true),
      confidence:      0.90,
    );
  }

  // ── Pattern: SBI debit ────────────────────────────────────────────────────
  // "Your A/c no. XX5678 is debited for Rs.1000.00 on 17/03/26 by transfer to RAZORPAY."
  static SMSTransaction? _trySbiDebit(String sms, String today) {
    final re = RegExp(
      r'[Aa]/[Cc]\s+no\.?\s+[xX]+(\d{4})\s+is\s+debited\s+for\s+'
      r'[Rr]s\.?\s*([\d,]+\.?\d*)(?:\s+on\s+([\d\-/]+))?'
      r'(?:.*?to\s+([A-Z][^\.\n]{1,40}))?',
      caseSensitive: false,
    );
    final m = re.firstMatch(sms);
    if (m == null) return null;
    final merchant = _clean(m.group(4));
    return SMSTransaction(
      isTransaction:   true,
      transactionType: 'debit',
      amount:          _amt(m.group(2)!),
      merchant:        merchant,
      accountLast4:    m.group(1),
      bankName:        'SBI',
      transactionDate: _date(m.group(3)) ?? today,
      category:        _cat(merchant, isIncome: false),
      confidence:      0.90,
    );
  }

  // ── Pattern: ICICI debit ──────────────────────────────────────────────────
  // "ICICI Bank: Rs.850.00 debited from XX9012 on 17-Mar-26 towards UPI/ref no 123456789."
  static SMSTransaction? _tryIciciDebit(String sms, String today) {
    final re = RegExp(
      r'ICICI\s+Bank[:\s]+[Rr]s\.?\s*([\d,]+\.?\d*)\s+debited\s+from\s+[xX]+(\d{4})'
      r'(?:\s+on\s+([\d\-A-Za-z]+))?(?:.*?towards\s+([^\.\n/]{2,40}))?',
      caseSensitive: false,
    );
    final m = re.firstMatch(sms);
    if (m == null) return null;
    final merchant = _clean(m.group(4))?.replaceAll(RegExp(r'^UPI$', caseSensitive: false), null.toString());
    return SMSTransaction(
      isTransaction:   true,
      transactionType: 'debit',
      amount:          _amt(m.group(1)!),
      merchant:        merchant?.isEmpty == true ? null : merchant,
      accountLast4:    m.group(2),
      bankName:        'ICICI Bank',
      transactionDate: _date(m.group(3)) ?? today,
      category:        _cat(merchant, isIncome: false),
      paymentMode:     'UPI',
      confidence:      0.88,
    );
  }

  // ── Pattern: Axis debit ───────────────────────────────────────────────────
  // "Rs.500 debited from Axis Acct XX3456 for POS txn at DMART on 17-03-2026."
  static SMSTransaction? _tryAxisDebit(String sms, String today) {
    final re = RegExp(
      r'[Rr]s\.?\s*([\d,]+\.?\d*)\s+debited\s+from\s+Axis\s+[Aa]cct\s+[xX]+(\d{4})'
      r'(?:.*?at\s+([A-Z][^\s][^\.\n]{1,30}))?(?:.*?on\s+([\d\-/]+))?',
      caseSensitive: false,
    );
    final m = re.firstMatch(sms);
    if (m == null) return null;
    final merchant = _clean(m.group(3));
    return SMSTransaction(
      isTransaction:   true,
      transactionType: 'debit',
      amount:          _amt(m.group(1)!),
      merchant:        merchant,
      accountLast4:    m.group(2),
      bankName:        'Axis Bank',
      transactionDate: _date(m.group(4)) ?? today,
      category:        _cat(merchant, isIncome: false),
      paymentMode:     'POS',
      confidence:      0.88,
    );
  }

  // ── Pattern: UPI paid (PhonePe / GPay) ───────────────────────────────────
  // "Rs.500.00 paid to Swiggy India Private Limited via PhonePe on 17-Mar-2026."
  static SMSTransaction? _tryUpiPaid(String sms, String today) {
    final re = RegExp(
      r'[Rr]s\.?\s*([\d,]+\.?\d*)\s+paid\s+to\s+(.+?)\s+via\s+(PhonePe|GPay|Paytm|BHIM|Google\s*Pay)',
      caseSensitive: false,
    );
    final m = re.firstMatch(sms);
    if (m == null) return null;
    final merchant = _clean(m.group(2));
    return SMSTransaction(
      isTransaction:   true,
      transactionType: 'debit',
      amount:          _amt(m.group(1)!),
      merchant:        merchant,
      transactionDate: today,
      category:        _cat(merchant, isIncome: false),
      paymentMode:     'UPI',
      confidence:      0.90,
    );
  }

  // ── Pattern: UPI received ─────────────────────────────────────────────────
  // "Rs.500.00 received from Ravi Kumar in your HDFC Bank A/c XX1234 on 17-Mar-26."
  static SMSTransaction? _tryUpiReceived(String sms, String today) {
    final re = RegExp(
      r'[Rr]s\.?\s*([\d,]+\.?\d*)\s+received\s+from\s+(.+?)\s+'
      r'(?:in\s+your|to\s+your|on)',
      caseSensitive: false,
    );
    final m = re.firstMatch(sms);
    if (m == null) return null;
    final merchant = _clean(m.group(2));
    return SMSTransaction(
      isTransaction:   true,
      transactionType: 'credit',
      amount:          _amt(m.group(1)!),
      merchant:        merchant,
      transactionDate: today,
      category:        'Transfer',
      paymentMode:     'UPI',
      confidence:      0.88,
    );
  }

  // ── Pattern: Salary credit ────────────────────────────────────────────────
  // "Salary of INR 75,000.00 credited to your A/c XX7890 on 17-03-2026 by TCS LIMITED."
  static SMSTransaction? _trySalaryCredit(String sms, String today) {
    final lower = sms.toLowerCase();
    if (!lower.contains('salary') && !lower.contains('payroll')) return null;
    final re = RegExp(
      r'(?:INR|Rs\.?)\s*([\d,]+\.?\d*).*credited.*by\s+([A-Z][^\.\n]{2,40})',
      caseSensitive: false,
    );
    final m = re.firstMatch(sms);
    if (m == null) return null;
    final merchant = _clean(m.group(2));
    return SMSTransaction(
      isTransaction:   true,
      transactionType: 'credit',
      amount:          _amt(m.group(1)!),
      merchant:        merchant,
      transactionDate: today,
      category:        '💼 Salary',
      confidence:      0.92,
    );
  }

  // ── Generic fallback patterns ─────────────────────────────────────────────

  static SMSTransaction? _tryGenericDebit(String sms, String today) {
    final re = RegExp(
      r'(?:INR|Rs\.?|₹)\s*([\d,]+\.?\d*).*?(?:debited|deducted|paid|spent|withdrawn)',
      caseSensitive: false,
    );
    final m = re.firstMatch(sms);
    if (m == null) return null;
    return SMSTransaction(
      isTransaction:   true,
      transactionType: 'debit',
      amount:          _amt(m.group(1)!),
      transactionDate: today,
      category:        'Other',
      confidence:      0.65,
    );
  }

  static SMSTransaction? _tryGenericCredit(String sms, String today) {
    final re = RegExp(
      r'(?:INR|Rs\.?|₹)\s*([\d,]+\.?\d*).*?(?:credited|received|deposited)',
      caseSensitive: false,
    );
    final m = re.firstMatch(sms);
    if (m == null) return null;
    return SMSTransaction(
      isTransaction:   true,
      transactionType: 'credit',
      amount:          _amt(m.group(1)!),
      transactionDate: today,
      category:        'Other',
      confidence:      0.60,
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static double _amt(String raw) =>
      double.tryParse(raw.replaceAll(',', '').trim()) ?? 0.0;

  static String? _clean(String? raw) {
    if (raw == null) return null;
    final s = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    return s.isEmpty ? null : s;
  }

  static String? _date(String? raw) {
    if (raw == null) return null;
    // Normalise common Indian date formats: 17-03-26, 17/03/2026, 17-Mar-26
    final s = raw.trim();
    try {
      // dd-MMM-yy  e.g. 17-Mar-26
      final monthAbbr = {
        'jan': '01', 'feb': '02', 'mar': '03', 'apr': '04',
        'may': '05', 'jun': '06', 'jul': '07', 'aug': '08',
        'sep': '09', 'oct': '10', 'nov': '11', 'dec': '12',
      };
      final alphaRe = RegExp(r'^(\d{1,2})[/-]([A-Za-z]{3})[/-](\d{2,4})$');
      final am = alphaRe.firstMatch(s);
      if (am != null) {
        final dd = am.group(1)!.padLeft(2, '0');
        final mm = monthAbbr[am.group(2)!.toLowerCase()] ?? '01';
        var yy = am.group(3)!;
        if (yy.length == 2) yy = '20$yy';
        return '$yy-$mm-$dd';
      }
      // dd-mm-yy or dd/mm/yyyy
      final numRe = RegExp(r'^(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})$');
      final nm = numRe.firstMatch(s);
      if (nm != null) {
        final dd = nm.group(1)!.padLeft(2, '0');
        final mm = nm.group(2)!.padLeft(2, '0');
        var yy = nm.group(3)!;
        if (yy.length == 2) yy = '20$yy';
        return '$yy-$mm-$dd';
      }
    } catch (_) {}
    return null;
  }

  static String _cat(String? merchant, {required bool isIncome}) {
    return CategoryDetector.detect(merchant ?? '', isIncome: isIncome) ??
        (isIncome ? 'Income' : 'Other');
  }
}
