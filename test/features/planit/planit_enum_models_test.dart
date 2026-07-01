import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:wai_life_assistant/data/models/planit/planit_models.dart';

void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // 1. Priority — label and color
  // ═══════════════════════════════════════════════════════════════════════════
  group('Priority.label', () {
    test('low → "Low"', () => expect(Priority.low.label, 'Low'));
    test('medium → "Medium"', () => expect(Priority.medium.label, 'Medium'));
    test('high → "High"', () => expect(Priority.high.label, 'High'));
    test('urgent → "Urgent"', () => expect(Priority.urgent.label, 'Urgent'));
    test('all 4 values have non-empty label', () {
      expect(Priority.values.length, 4);
      for (final p in Priority.values) {
        expect(p.label, isNotEmpty, reason: p.name);
      }
    });
  });

  group('Priority.color', () {
    test('low → Color(0xFF00C897)', () => expect(Priority.low.color, const Color(0xFF00C897)));
    test('medium → Color(0xFF4A9EFF)', () => expect(Priority.medium.color, const Color(0xFF4A9EFF)));
    test('high → Color(0xFFFFAA2C)', () => expect(Priority.high.color, const Color(0xFFFFAA2C)));
    test('urgent → Color(0xFFFF5C7A)', () => expect(Priority.urgent.color, const Color(0xFFFF5C7A)));
    test('all 4 values return distinct colors', () {
      final colors = Priority.values.map((p) => p.color).toSet();
      expect(colors.length, 4);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. RepeatMode — label and badge
  // ═══════════════════════════════════════════════════════════════════════════
  group('RepeatMode.label', () {
    test('none → "No repeat"', () => expect(RepeatMode.none.label, 'No repeat'));
    test('daily → "Daily"', () => expect(RepeatMode.daily.label, 'Daily'));
    test('weekly → "Weekly"', () => expect(RepeatMode.weekly.label, 'Weekly'));
    test('monthly → "Monthly"', () => expect(RepeatMode.monthly.label, 'Monthly'));
    test('yearly → "Yearly"', () => expect(RepeatMode.yearly.label, 'Yearly'));
    test('all 5 values have non-empty label', () {
      expect(RepeatMode.values.length, 5);
      for (final r in RepeatMode.values) {
        expect(r.label, isNotEmpty, reason: r.name);
      }
    });
  });

  group('RepeatMode.badge', () {
    test('none → "" (empty string — no badge shown)', () {
      expect(RepeatMode.none.badge, '');
    });
    test('daily → "🔁 Daily"', () => expect(RepeatMode.daily.badge, '🔁 Daily'));
    test('weekly → "🔁 Weekly"', () => expect(RepeatMode.weekly.badge, '🔁 Weekly'));
    test('monthly → "🔁 Monthly"', () => expect(RepeatMode.monthly.badge, '🔁 Monthly'));
    test('yearly → "🔁 Yearly"', () => expect(RepeatMode.yearly.badge, '🔁 Yearly'));
    test('all non-none values start with "🔁 "', () {
      for (final r in RepeatMode.values) {
        if (r == RepeatMode.none) continue;
        expect(r.badge, startsWith('🔁 '), reason: r.name);
      }
    });
    test('badge label matches mode label for non-none values', () {
      for (final r in RepeatMode.values) {
        if (r == RepeatMode.none) continue;
        expect(r.badge, contains(r.label), reason: r.name);
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 3. TaskStatus — label, color, icon
  // ═══════════════════════════════════════════════════════════════════════════
  group('TaskStatus.label', () {
    test('todo → "To Do"', () => expect(TaskStatus.todo.label, 'To Do'));
    test('inProgress → "In Progress"', () => expect(TaskStatus.inProgress.label, 'In Progress'));
    test('done → "Done"', () => expect(TaskStatus.done.label, 'Done'));
    test('all 3 values have non-empty label', () {
      expect(TaskStatus.values.length, 3);
      for (final s in TaskStatus.values) {
        expect(s.label, isNotEmpty, reason: s.name);
      }
    });
  });

  group('TaskStatus.color', () {
    test('todo → Color(0xFF6C63FF)', () => expect(TaskStatus.todo.color, const Color(0xFF6C63FF)));
    test('inProgress → Color(0xFFFFAA2C)', () => expect(TaskStatus.inProgress.color, const Color(0xFFFFAA2C)));
    test('done → Color(0xFF00C897)', () => expect(TaskStatus.done.color, const Color(0xFF00C897)));
    test('all 3 values return distinct colors', () {
      final colors = TaskStatus.values.map((s) => s.color).toSet();
      expect(colors.length, 3);
    });
  });

  group('TaskStatus.icon', () {
    test('todo → Icons.radio_button_unchecked_rounded', () {
      expect(TaskStatus.todo.icon, Icons.radio_button_unchecked_rounded);
    });
    test('inProgress → Icons.timelapse_rounded', () {
      expect(TaskStatus.inProgress.icon, Icons.timelapse_rounded);
    });
    test('done → Icons.check_circle_rounded', () {
      expect(TaskStatus.done.icon, Icons.check_circle_rounded);
    });
    test('all 3 values return distinct icons', () {
      final icons = TaskStatus.values.map((s) => s.icon).toSet();
      expect(icons.length, 3);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 4. SpecialDayType — label, emoji, color
  // ═══════════════════════════════════════════════════════════════════════════
  group('SpecialDayType.label', () {
    test('birthday → "Birthday"', () => expect(SpecialDayType.birthday.label, 'Birthday'));
    test('anniversary → "Anniversary"', () => expect(SpecialDayType.anniversary.label, 'Anniversary'));
    test('festival → "Festival"', () => expect(SpecialDayType.festival.label, 'Festival'));
    test('govtHoliday → "Govt Holiday"', () => expect(SpecialDayType.govtHoliday.label, 'Govt Holiday'));
    test('holiday → "Holiday"', () => expect(SpecialDayType.holiday.label, 'Holiday'));
    test('custom → "Custom"', () => expect(SpecialDayType.custom.label, 'Custom'));
    test('all 6 values have non-empty label', () {
      expect(SpecialDayType.values.length, 6);
      for (final t in SpecialDayType.values) {
        expect(t.label, isNotEmpty, reason: t.name);
      }
    });
  });

  group('SpecialDayType.emoji', () {
    test('birthday → "🎂"', () => expect(SpecialDayType.birthday.emoji, '🎂'));
    test('anniversary → "💍"', () => expect(SpecialDayType.anniversary.emoji, '💍'));
    test('festival → "🎉"', () => expect(SpecialDayType.festival.emoji, '🎉'));
    test('govtHoliday → "🏛️"', () => expect(SpecialDayType.govtHoliday.emoji, '🏛️'));
    test('holiday → "🌟"', () => expect(SpecialDayType.holiday.emoji, '🌟'));
    test('custom → "📅"', () => expect(SpecialDayType.custom.emoji, '📅'));
    test('all 6 values have non-empty emoji', () {
      for (final t in SpecialDayType.values) {
        expect(t.emoji, isNotEmpty, reason: t.name);
      }
    });
  });

  group('SpecialDayType.color', () {
    test('birthday → Color(0xFFFF5C7A)', () => expect(SpecialDayType.birthday.color, const Color(0xFFFF5C7A)));
    test('anniversary → Color(0xFFFFAA2C)', () => expect(SpecialDayType.anniversary.color, const Color(0xFFFFAA2C)));
    test('festival → Color(0xFF6C63FF)', () => expect(SpecialDayType.festival.color, const Color(0xFF6C63FF)));
    test('govtHoliday → Color(0xFF1A8FE3)', () => expect(SpecialDayType.govtHoliday.color, const Color(0xFF1A8FE3)));
    test('holiday → Color(0xFF00C897)', () => expect(SpecialDayType.holiday.color, const Color(0xFF00C897)));
    test('custom → Color(0xFF4A9EFF)', () => expect(SpecialDayType.custom.color, const Color(0xFF4A9EFF)));
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 5. WishCategory — label and emoji
  // ═══════════════════════════════════════════════════════════════════════════
  group('WishCategory.label', () {
    test('electronics → "Electronics"', () => expect(WishCategory.electronics.label, 'Electronics'));
    test('fashion → "Fashion"', () => expect(WishCategory.fashion.label, 'Fashion'));
    test('home → "Home"', () => expect(WishCategory.home.label, 'Home'));
    test('travel → "Travel"', () => expect(WishCategory.travel.label, 'Travel'));
    test('food → "Food"', () => expect(WishCategory.food.label, 'Food'));
    test('experience → "Experience"', () => expect(WishCategory.experience.label, 'Experience'));
    test('other → "Other"', () => expect(WishCategory.other.label, 'Other'));
    test('all 7 values have non-empty label', () {
      expect(WishCategory.values.length, 7);
      for (final c in WishCategory.values) {
        expect(c.label, isNotEmpty, reason: c.name);
      }
    });
  });

  group('WishCategory.emoji', () {
    test('electronics → "💻"', () => expect(WishCategory.electronics.emoji, '💻'));
    test('fashion → "👗"', () => expect(WishCategory.fashion.emoji, '👗'));
    test('home → "🏠"', () => expect(WishCategory.home.emoji, '🏠'));
    test('travel → "✈️"', () => expect(WishCategory.travel.emoji, '✈️'));
    test('food → "🍽️"', () => expect(WishCategory.food.emoji, '🍽️'));
    test('experience → "🎭"', () => expect(WishCategory.experience.emoji, '🎭'));
    test('other → "🎁"', () => expect(WishCategory.other.emoji, '🎁'));
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 6. BillCategory — label and emoji (12 values)
  // ═══════════════════════════════════════════════════════════════════════════
  group('BillCategory.label', () {
    test('electricity → "Electricity"', () => expect(BillCategory.electricity.label, 'Electricity'));
    test('water → "Water"', () => expect(BillCategory.water.label, 'Water'));
    test('gas → "Gas"', () => expect(BillCategory.gas.label, 'Gas'));
    test('internet → "Internet"', () => expect(BillCategory.internet.label, 'Internet'));
    test('phone → "Phone"', () => expect(BillCategory.phone.label, 'Phone'));
    test('insurance → "Insurance"', () => expect(BillCategory.insurance.label, 'Insurance'));
    test('school → "School Fees" (not "School")', () => expect(BillCategory.school.label, 'School Fees'));
    test('rent → "Rent"', () => expect(BillCategory.rent.label, 'Rent'));
    test('subscription → "Subscription"', () => expect(BillCategory.subscription.label, 'Subscription'));
    test('medical → "Medical"', () => expect(BillCategory.medical.label, 'Medical'));
    test('emi → "EMI"', () => expect(BillCategory.emi.label, 'EMI'));
    test('other → "Other"', () => expect(BillCategory.other.label, 'Other'));
    test('all 12 values have non-empty label', () {
      expect(BillCategory.values.length, 12);
      for (final c in BillCategory.values) {
        expect(c.label, isNotEmpty, reason: c.name);
      }
    });
  });

  group('BillCategory.emoji', () {
    test('electricity → "💡"', () => expect(BillCategory.electricity.emoji, '💡'));
    test('water → "💧"', () => expect(BillCategory.water.emoji, '💧'));
    test('gas → "🔥"', () => expect(BillCategory.gas.emoji, '🔥'));
    test('internet → "📡"', () => expect(BillCategory.internet.emoji, '📡'));
    test('phone → "📱"', () => expect(BillCategory.phone.emoji, '📱'));
    test('insurance → "🛡️"', () => expect(BillCategory.insurance.emoji, '🛡️'));
    test('school → "🎒"', () => expect(BillCategory.school.emoji, '🎒'));
    test('rent → "🏠"', () => expect(BillCategory.rent.emoji, '🏠'));
    test('subscription → "📺"', () => expect(BillCategory.subscription.emoji, '📺'));
    test('medical → "🏥"', () => expect(BillCategory.medical.emoji, '🏥'));
    test('emi → "🏦"', () => expect(BillCategory.emi.emoji, '🏦'));
    test('other → "📋"', () => expect(BillCategory.other.emoji, '📋'));
    test('all 12 values have non-empty emoji', () {
      for (final c in BillCategory.values) {
        expect(c.emoji, isNotEmpty, reason: c.name);
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 7. TravelMode — label and emoji
  // ═══════════════════════════════════════════════════════════════════════════
  group('TravelMode.label', () {
    test('flight → "Flight"', () => expect(TravelMode.flight.label, 'Flight'));
    test('train → "Train"', () => expect(TravelMode.train.label, 'Train'));
    test('car → "Car"', () => expect(TravelMode.car.label, 'Car'));
    test('bus → "Bus"', () => expect(TravelMode.bus.label, 'Bus'));
    test('bike → "Bike"', () => expect(TravelMode.bike.label, 'Bike'));
    test('ship → "Ship"', () => expect(TravelMode.ship.label, 'Ship'));
    test('mixed → "Mixed"', () => expect(TravelMode.mixed.label, 'Mixed'));
    test('all 7 values have non-empty label', () {
      expect(TravelMode.values.length, 7);
      for (final m in TravelMode.values) {
        expect(m.label, isNotEmpty, reason: m.name);
      }
    });
  });

  group('TravelMode.emoji', () {
    test('flight → "✈️"', () => expect(TravelMode.flight.emoji, '✈️'));
    test('train → "🚆"', () => expect(TravelMode.train.emoji, '🚆'));
    test('car → "🚗"', () => expect(TravelMode.car.emoji, '🚗'));
    test('bus → "🚌"', () => expect(TravelMode.bus.emoji, '🚌'));
    test('bike → "🏍️"', () => expect(TravelMode.bike.emoji, '🏍️'));
    test('ship → "🚢"', () => expect(TravelMode.ship.emoji, '🚢'));
    test('mixed → "🗺️"', () => expect(TravelMode.mixed.emoji, '🗺️'));
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 8. HealthRecordType — label, emoji, color
  // ═══════════════════════════════════════════════════════════════════════════
  group('HealthRecordType.label', () {
    test('prescription → "Prescription"', () => expect(HealthRecordType.prescription.label, 'Prescription'));
    test('report → "Lab Report" (not "Report")', () => expect(HealthRecordType.report.label, 'Lab Report'));
    test('vaccination → "Vaccination"', () => expect(HealthRecordType.vaccination.label, 'Vaccination'));
    test('vitals → "Vitals"', () => expect(HealthRecordType.vitals.label, 'Vitals'));
    test('allergy → "Allergy"', () => expect(HealthRecordType.allergy.label, 'Allergy'));
    test('surgery → "Surgery"', () => expect(HealthRecordType.surgery.label, 'Surgery'));
    test('other → "Other"', () => expect(HealthRecordType.other.label, 'Other'));
    test('all 7 values have non-empty label', () {
      expect(HealthRecordType.values.length, 7);
      for (final t in HealthRecordType.values) {
        expect(t.label, isNotEmpty, reason: t.name);
      }
    });
  });

  group('HealthRecordType.emoji', () {
    test('prescription → "💊"', () => expect(HealthRecordType.prescription.emoji, '💊'));
    test('report → "🔬"', () => expect(HealthRecordType.report.emoji, '🔬'));
    test('vaccination → "💉"', () => expect(HealthRecordType.vaccination.emoji, '💉'));
    test('vitals → "❤️"', () => expect(HealthRecordType.vitals.emoji, '❤️'));
    test('allergy → "⚠️"', () => expect(HealthRecordType.allergy.emoji, '⚠️'));
    test('surgery → "🏥"', () => expect(HealthRecordType.surgery.emoji, '🏥'));
    test('other → "📋"', () => expect(HealthRecordType.other.emoji, '📋'));
    test('all 7 values have non-empty emoji', () {
      for (final t in HealthRecordType.values) {
        expect(t.emoji, isNotEmpty, reason: t.name);
      }
    });
  });

  group('HealthRecordType.color', () {
    test('prescription → Color(0xFF6C63FF)', () => expect(HealthRecordType.prescription.color, const Color(0xFF6C63FF)));
    test('report → Color(0xFF4A9EFF)', () => expect(HealthRecordType.report.color, const Color(0xFF4A9EFF)));
    test('vaccination → Color(0xFF00C897)', () => expect(HealthRecordType.vaccination.color, const Color(0xFF00C897)));
    test('vitals → Color(0xFFFF5C7A)', () => expect(HealthRecordType.vitals.color, const Color(0xFFFF5C7A)));
    test('allergy → Color(0xFFFFAA2C)', () => expect(HealthRecordType.allergy.color, const Color(0xFFFFAA2C)));
    test('surgery → Color(0xFFFF7043)', () => expect(HealthRecordType.surgery.color, const Color(0xFFFF7043)));
    test('other → Color(0xFF8E8EA0)', () => expect(HealthRecordType.other.color, const Color(0xFF8E8EA0)));
    test('all 7 values return distinct colors', () {
      final colors = HealthRecordType.values.map((t) => t.color).toSet();
      expect(colors.length, 7);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 9. TripStatus — label and emoji
  // ═══════════════════════════════════════════════════════════════════════════
  group('TripStatus.label', () {
    test('planning → "Planning"', () => expect(TripStatus.planning.label, 'Planning'));
    test('confirmed → "Confirmed"', () => expect(TripStatus.confirmed.label, 'Confirmed'));
    test('ongoing → "Ongoing"', () => expect(TripStatus.ongoing.label, 'Ongoing'));
    test('completed → "Completed"', () => expect(TripStatus.completed.label, 'Completed'));
    test('cancelled → "Cancelled"', () => expect(TripStatus.cancelled.label, 'Cancelled'));
    test('all 5 values have non-empty label', () {
      expect(TripStatus.values.length, 5);
      for (final s in TripStatus.values) {
        expect(s.label, isNotEmpty, reason: s.name);
      }
    });
  });

  group('TripStatus.emoji', () {
    test('planning → "📝"', () => expect(TripStatus.planning.emoji, '📝'));
    test('confirmed → "✅"', () => expect(TripStatus.confirmed.emoji, '✅'));
    test('ongoing → "🚀"', () => expect(TripStatus.ongoing.emoji, '🚀'));
    test('completed → "🏁"', () => expect(TripStatus.completed.emoji, '🏁'));
    test('cancelled → "❌"', () => expect(TripStatus.cancelled.emoji, '❌'));
    test('all 5 values have non-empty emoji', () {
      for (final s in TripStatus.values) {
        expect(s.emoji, isNotEmpty, reason: s.name);
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 10. TaskCategory — label and emoji
  // ═══════════════════════════════════════════════════════════════════════════
  group('TaskCategory.label', () {
    test('booking → "Booking"', () => expect(TaskCategory.booking.label, 'Booking'));
    test('packing → "Packing"', () => expect(TaskCategory.packing.label, 'Packing'));
    test('document → "Documents" (plural)', () => expect(TaskCategory.document.label, 'Documents'));
    test('activity → "Activity"', () => expect(TaskCategory.activity.label, 'Activity'));
    test('food → "Food"', () => expect(TaskCategory.food.label, 'Food'));
    test('transport → "Transport"', () => expect(TaskCategory.transport.label, 'Transport'));
    test('accommodation → "Stay" (not "Accommodation")', () => expect(TaskCategory.accommodation.label, 'Stay'));
    test('other → "Other"', () => expect(TaskCategory.other.label, 'Other'));
    test('all 8 values have non-empty label', () {
      expect(TaskCategory.values.length, 8);
      for (final c in TaskCategory.values) {
        expect(c.label, isNotEmpty, reason: c.name);
      }
    });
  });

  group('TaskCategory.emoji', () {
    test('booking → "🎫"', () => expect(TaskCategory.booking.emoji, '🎫'));
    test('packing → "🧳"', () => expect(TaskCategory.packing.emoji, '🧳'));
    test('document → "📄"', () => expect(TaskCategory.document.emoji, '📄'));
    test('activity → "🎯"', () => expect(TaskCategory.activity.emoji, '🎯'));
    test('food → "🍽️"', () => expect(TaskCategory.food.emoji, '🍽️'));
    test('transport → "🚌"', () => expect(TaskCategory.transport.emoji, '🚌'));
    test('accommodation → "🏨"', () => expect(TaskCategory.accommodation.emoji, '🏨'));
    test('other → "📌"', () => expect(TaskCategory.other.emoji, '📌'));
    test('all 8 values have non-empty emoji', () {
      for (final c in TaskCategory.values) {
        expect(c.emoji, isNotEmpty, reason: c.name);
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 11. Cross-cutting invariants
  // ═══════════════════════════════════════════════════════════════════════════
  group('cross-cutting invariants', () {
    test('RepeatMode.none badge is empty — all other badges are non-empty', () {
      expect(RepeatMode.none.badge, isEmpty);
      for (final r in RepeatMode.values) {
        if (r != RepeatMode.none) expect(r.badge, isNotEmpty, reason: r.name);
      }
    });

    test('Priority colors are all fully-opaque (alpha = 0xFF)', () {
      for (final p in Priority.values) {
        expect(p.color.a, 1.0, reason: p.name);
      }
    });

    test('SpecialDayType colors are all fully-opaque', () {
      for (final t in SpecialDayType.values) {
        expect(t.color.a, 1.0, reason: t.name);
      }
    });

    test('HealthRecordType colors are all fully-opaque', () {
      for (final t in HealthRecordType.values) {
        expect(t.color.a, 1.0, reason: t.name);
      }
    });

    test('TaskStatus.inProgress serialises as "inProgress" (camelCase, not snake_case)', () {
      expect(TaskStatus.inProgress.name, 'inProgress');
    });

    test('SpecialDayType.govtHoliday serialises as "govtHoliday"', () {
      expect(SpecialDayType.govtHoliday.name, 'govtHoliday');
    });

    test('TaskCategory.accommodation serialises as "accommodation" (enum name != label "Stay")', () {
      expect(TaskCategory.accommodation.name, 'accommodation');
      expect(TaskCategory.accommodation.label, 'Stay');
      expect(TaskCategory.accommodation.name, isNot(TaskCategory.accommodation.label));
    });

    test('HealthRecordType.report enum name is "report" but label is "Lab Report"', () {
      expect(HealthRecordType.report.name, 'report');
      expect(HealthRecordType.report.label, 'Lab Report');
    });
  });
}
